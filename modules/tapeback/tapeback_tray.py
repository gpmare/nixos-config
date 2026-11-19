"""Tray front-end for tapeback: record on this machine, hand the audio to the worker.

Runs inside tapeback's venv. It is tapeback's own tray with one change: when you
click Stop it does NOT transcribe here. It merges the two channels into one 16 kHz
stereo WAV (mic on the left, system audio on the right), drops it in the outbox and
starts tapeback-handoff, which gets it to the nucbox. The recording session is kept
until the WAV is safely in the outbox, so a failure never loses a meeting.
"""

import logging
import os
import shutil
import subprocess
from pathlib import Path

from tapeback.audio import merge_channels
from tapeback.settings import get_settings
from tapeback.tray import TrayApp, TrayState, _warn_if_tray_host_missing
from tapeback._tray_env import detect_tray_env

logger = logging.getLogger("tapeback-tray")

STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "tapeback"
OUTBOX = STATE / "outbox"


def _notify(summary: str, body: str = "") -> None:
    try:
        subprocess.run(
            ["notify-send", "--app-name=tapeback", "--icon=audio-input-microphone", summary, body],
            check=False,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        pass


class HandoffTray(TrayApp):
    def _do_stop_and_process(self) -> None:  # noqa: D401 - overrides tapeback's
        try:
            monitor, mic = self._recorder.stop()
            session_dir = monitor.parent
            name = session_dir.name
            stereo = merge_channels(monitor, mic, session_dir)

            OUTBOX.mkdir(parents=True, exist_ok=True)
            tmp = OUTBOX / f".{name}.wav.tmp"
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", str(stereo),
                 "-ar", "16000", "-c:a", "pcm_s16le", "-f", "wav", str(tmp)],
                check=True,
            )
            os.replace(tmp, OUTBOX / f"{name}.wav")
            shutil.rmtree(session_dir, ignore_errors=True)
            logger.info("Recording %s is in the outbox, handing off", name)
            subprocess.Popen(["systemctl", "--user", "start", "--no-block", "tapeback-handoff.service"])
            _notify("Recording saved", "Sending it for transcription. The note will appear in Meetings/Inbox.")
        except Exception:
            logger.exception("Could not queue the recording; the raw session is kept in ~/.local/state/tapeback/sessions")
            _notify("tapeback: recording NOT queued", "The raw audio is kept. Check the tray log.")
        finally:
            self._update_state_threadsafe(TrayState.IDLE)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    _warn_if_tray_host_missing(detect_tray_env())
    HandoffTray(get_settings()).run()


if __name__ == "__main__":
    main()
