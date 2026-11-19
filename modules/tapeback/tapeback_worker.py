"""Transcribe and diarize queued recordings, write ONLY a Markdown note to the vault.

Runs on the nucbox inside tapeback's venv, started by tapeback-worker.service.

For each WAV in the inbox it runs tapeback's own pipeline (faster-whisper + pyannote)
with the "vault" pointed at a private staging folder, so tapeback's habit of copying
the audio next to the note never touches the real vault. Then it rewrites the note's
frontmatter to the Meetings convention, moves the note into Meetings/Inbox, and
deletes the WAV, the staged copy and the staged note. A recording that fails goes to
failed/ and is never deleted.
"""

import fcntl
import os
import re
import shutil
import sys
import time
import traceback
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "tapeback"
INBOX = STATE / "inbox"
FAILED = STATE / "failed"
STAGING = Path(os.environ["TAPEBACK_VAULT_PATH"]).expanduser()
NOTES_OUT = Path(os.environ["TAPEBACK_NOTES_DIR"]).expanduser()
LANGS = [x.strip() for x in os.environ.get("TAPEBACK_LANGUAGES", "").split(",") if x.strip()]
DIARIZE_MODE = os.environ.get("TAPEBACK_WORKER_DIARIZE", "auto")  # auto | off


def log(msg: str) -> None:
    print(f"[tapeback-worker] {msg}", flush=True)


def restrict_languages(allowed: list[str]) -> None:
    """Make Whisper pick between only these languages (default: Afrikaans and English).

    Whisper's detector chooses among ~100 languages and Afrikaans is easily mistaken
    for Dutch. With multilingual mode on, tapeback re-detects on every 30 s window, so
    restricting the candidates is what keeps mixed af/en meetings spelled correctly.
    """
    import ctranslate2

    wanted = {f"<|{lang}|>" for lang in allowed}
    base = ctranslate2.models.Whisper

    class RestrictedWhisper(base):  # type: ignore[misc, valid-type]
        def detect_language(self, features):  # noqa: ANN001
            out = []
            for result in super().detect_language(features):
                kept = [(tok, p) for tok, p in result if tok in wanted]
                if not kept:
                    out.append(result)
                    continue
                total = sum(p for _, p in kept) or 1.0
                out.append([(tok, p / total) for tok, p in kept])
            return out

    ctranslate2.models.Whisper = RestrictedWhisper
    log(f"language detection restricted to: {', '.join(allowed)}")


_FM = re.compile(r"\A---\n(.*?)\n---\n", re.S)


def _field(front: str, key: str) -> str:
    m = re.search(rf"^{key}:\s*(.*)$", front, re.M)
    return m.group(1).strip().strip('"') if m else ""


def to_vault_note(markdown: str) -> str:
    """Rewrite tapeback's frontmatter to the vault's Meetings convention. No audio link."""
    m = _FM.match(markdown)
    front, body = (m.group(1), markdown[m.end():]) if m else ("", markdown)
    partial = "partial: true" in front
    tags = "[meeting, transcript, partial]" if partial else "[meeting, transcript]"
    lines = [
        "---",
        "type: meeting",
        f"date: {_field(front, 'date')}",
        f'time: "{_field(front, "time")}"',
        f'duration: "{_field(front, "duration")}"',
        f"language: {_field(front, 'language')}",
        "title:",
        "venture:",
        "attendees: []",
        "status: untriaged",
        "summary:",
        "action_items: []",
        "source: tapeback",
        "privacy: normal",
        "publish: false",
        f"tags: {tags}",
    ]
    if partial:
        lines.append("partial: true")
    lines += ["---", ""]
    body = body.lstrip("\n")
    # Defensive: tapeback never puts an audio link in the body today, but drop any.
    body = "\n".join(ln for ln in body.split("\n") if "attachments/audio" not in ln and ".wav]]" not in ln)
    return "\n".join(lines) + body


def deliver(note_text: str, name: str) -> Path:
    NOTES_OUT.mkdir(parents=True, exist_ok=True)
    dest = NOTES_OUT / f"{name}.md"
    n = 1
    while dest.exists():
        dest = NOTES_OUT / f"{name}_{n}.md"
        n += 1
    tmp = STAGING / f".deliver-{name}.md"
    tmp.write_text(note_text, encoding="utf-8")
    if tmp.stat().st_dev == NOTES_OUT.stat().st_dev:
        os.replace(tmp, dest)  # atomic: Sync never sees a half-written note
    else:
        part = dest.with_name(f".{dest.name}.part")
        shutil.copyfile(tmp, part)
        os.replace(part, dest)
        tmp.unlink()
    return dest


def process_one(wav: Path, settings, want_diarize: bool) -> Path:
    from tapeback.pipeline import process_file

    name = re.sub(r"[^\w-]", "_", wav.stem)
    staged_note = None
    try:
        md_path = process_file(
            wav, settings, name=name, diarize=want_diarize, do_summarize=False, on_status=log
        )
        staged_note = md_path
        note = to_vault_note(md_path.read_text(encoding="utf-8"))
        dest = deliver(note, name)
        log(f"note written: {dest}")
        return dest
    finally:
        # Audio never stays anywhere but the inbox until the note exists.
        for stale in (STAGING / settings.attachments_dir).glob(f"{name}*.wav"):
            stale.unlink(missing_ok=True)
        if staged_note is not None:
            staged_note.unlink(missing_ok=True)


def prune_resume_cache(days: int = 14) -> None:
    root = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "tapeback" / "resume"
    if root.is_dir():
        cutoff = time.time() - days * 86400
        for f in root.glob("*"):
            if f.is_file() and f.stat().st_mtime < cutoff:
                f.unlink(missing_ok=True)


def main() -> int:
    INBOX.mkdir(parents=True, exist_ok=True)
    FAILED.mkdir(parents=True, exist_ok=True)
    STAGING.mkdir(parents=True, exist_ok=True)
    os.chmod(STAGING, 0o700)

    lock = open(STATE / "worker.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        log("another worker run is active; leaving the queue to it")
        return 0

    queue = sorted(p for p in INBOX.glob("*.wav") if not p.name.startswith("."))
    if not queue:
        return 0

    from tapeback.settings import get_settings

    settings = get_settings()
    has_token = bool(settings.hf_token.get_secret_value())
    want_diarize = settings.diarize and DIARIZE_MODE != "off"
    if want_diarize and not has_token:
        log(
            f"{len(queue)} recording(s) waiting: speaker separation needs the Hugging Face token "
            "in ~/.config/tapeback/.env (TAPEBACK_HF_TOKEN). Audio is kept; nothing is lost."
        )
        return 0

    if LANGS:
        try:
            restrict_languages(LANGS)
        except Exception:
            log("could not restrict languages; continuing with full auto-detect")
            traceback.print_exc()

    rc = 0
    for wav in queue:
        log(f"processing {wav.name} (diarize={want_diarize})")
        started = time.time()
        try:
            process_one(wav, settings, want_diarize)
        except Exception:
            traceback.print_exc()
            log(f"FAILED {wav.name}; moved to {FAILED}")
            shutil.move(str(wav), str(FAILED / wav.name))
            rc = 1
            continue
        wav.unlink()
        log(f"done {wav.name} in {time.time() - started:.0f}s; recording deleted")

    prune_resume_cache()
    return rc


if __name__ == "__main__":
    sys.exit(main())
