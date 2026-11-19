# Tapeback (meeting recorder)

Declared in `../tapeback.nix`; imported by `hosts/common.nix`. Nucbox is the worker
(`services.tapeback.role = "worker"` in its host file), Dell is a client.

## Flow

1. Launch **Tapeback** (app menu) → tray icon → Start Recording … Stop Recording.
   Records your mic (left channel) and the call audio (right channel) with PipeWire.
2. Stop merges both into one 16 kHz stereo WAV in `~/.local/state/tapeback/outbox/`
   and starts `tapeback-handoff`. On the Dell it is copied to the nucbox over Tailscale
   SSH (retried every 5 min if the nucbox is off); on the nucbox it just moves to the queue.
3. The nucbox worker (`tapeback-worker.service`, low priority) runs Whisper large-v3 on
   each channel and pyannote speaker diarization, then writes **only a Markdown note** to
   `Meetings/Inbox/` (`status: untriaged`, `source: tapeback`). Then it deletes the WAV.
   A failed recording moves to `~/.local/state/tapeback/failed/` and is kept.
4. Grok Bot triages the note as described in the vault's `Meetings/README.md`.

Audio is never written to the vault: tapeback's own "vault" is
`~/.local/share/tapeback/staging` and the worker moves just the note across.

## Hugging Face token (nucbox only, required for speaker separation)

pyannote's models are gated. Until the token exists the worker keeps recordings
queued and does nothing (`journalctl --user -u tapeback-worker`).

1. Log in to huggingface.co, accept the terms on:
   - https://huggingface.co/pyannote/speaker-diarization-3.1
   - https://huggingface.co/pyannote/segmentation-3.0
2. Settings → Access Tokens → create a token of type **Read** (or fine-grained with
   "read access to contents of all public gated repos").
3. On the nucbox run `tapeback-hf-token` and paste the token (typing is hidden). It is
   saved to `~/.config/tapeback/.env` with mode 600, outside the repo.

## Settings and why

See the `env` block in `../tapeback.nix`. Language: `auto` + `multilingual` (re-detect
every 30 s window) with candidates restricted to `af,en` by the worker, so mixed
Afrikaans/English meetings are neither forced into one language nor mistaken for Dutch.

## Updating tapeback or its dependencies

Edit `requirements-*.in`, then from this folder (on a machine with uv):

    uv pip compile requirements-worker.in --python $(nix build --no-link --print-out-paths nixpkgs#python313)/bin/python3.13 \
      --generate-hashes --index-strategy unsafe-best-match --extra-index-url https://download.pytorch.org/whl/cpu \
      -o requirements-worker.txt
    uv pip compile requirements-client.in --python .../python3.13 --generate-hashes -o requirements-client.txt

The next rebuild plus login (or `tapeback-setup`) rebuilds the venv when the
requirements file or the Nix python changes.

## Useful commands

    systemctl --user status tapeback-env tapeback-worker tapeback-handoff
    journalctl --user -u tapeback-worker -f
    ls ~/.local/state/tapeback/{outbox,inbox,failed}
    tapeback-setup           # (re)install the venv by hand
