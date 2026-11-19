# Tapeback (github.com/yastcher/tapeback): local meeting recorder with speaker
# separation. Recording happens on whichever machine you click Start on; ALL the
# heavy work (Whisper large-v3 + pyannote) happens on the nucbox.
#
#   role = "client"  (dell)    tray app records, ships the audio to the worker over
#                              Tailscale SSH, nothing heavy runs here.
#   role = "worker"  (nucbox)  tray app records too (hands off locally) AND runs the
#                              transcription queue as a low-priority user service.
#
# Only the Markdown note reaches the vault (Meetings/Inbox). Audio lives in
# ~/.local/state/tapeback until its note exists, then it is deleted.
# See modules/tapeback/README.md for the flow, the Hugging Face token and recovery.
#
# Python ML wheels are not packaged in Nix; instead tapeback and its dependencies
# are installed from a hash-pinned requirements file into ~/.local/share/tapeback/venv
# by tapeback-env.service, using Nix's python313 and uv. A stamp rebuilds the venv
# when the requirements or the Nix python change.

{ config, lib, pkgs, username, ... }:

let
  cfg = config.services.tapeback;
  home = "/home/${username}";
  py = pkgs.python313;
  worker = cfg.role == "worker";
  reqFile = if worker then ./tapeback/requirements-worker.txt else ./tapeback/requirements-client.txt;

  venv = "${home}/.local/share/tapeback/venv";
  state = "${home}/.local/state/tapeback";
  staging = "${home}/.local/share/tapeback/staging";
  remoteInbox = ".local/state/tapeback/inbox";

  # Settings shared by the tray, the CLI wrapper and the worker. tapeback reads them
  # as TAPEBACK_* environment variables; the Hugging Face token is NOT here, it lives
  # in ~/.config/tapeback/.env (outside the repo and the Nix store).
  env = {
    # Safety: tapeback's "vault" is a private staging folder, never the real vault.
    TAPEBACK_VAULT_PATH = staging;
    TAPEBACK_MEETINGS_DIR = "notes";
    TAPEBACK_ATTACHMENTS_DIR = "audio";
    TAPEBACK_LIVE = "false";        # no live transcription, no live notepad
    TAPEBACK_SUMMARIZE = "false";   # Grok Bot writes summaries from the transcript
  } // lib.optionalAttrs worker {
    TAPEBACK_NOTES_DIR = cfg.notesDir;
    TAPEBACK_STT_BACKEND = "local";
    TAPEBACK_STT_MODEL = cfg.whisperModel;   # large-v3: best Afrikaans; turbo/distil are weaker
    TAPEBACK_DEVICE = "cpu";                 # ctranslate2 has no ROCm build
    TAPEBACK_COMPUTE_TYPE = "int8";
    TAPEBACK_BEAM_SIZE = "5";
    TAPEBACK_LANGUAGE = "auto";
    TAPEBACK_MULTILINGUAL = "true";          # re-detect language every 30 s window
    TAPEBACK_LANGUAGES = "af,en";            # ...choosing only between Afrikaans and English
    TAPEBACK_LANGUAGE_DETECTION_SEGMENTS = "3";
    TAPEBACK_HALLUCINATION_SILENCE_THRESHOLD = "2.0";
    TAPEBACK_ISOLATE_TRANSCRIPTION = "false"; # needed for the language restriction
    TAPEBACK_DIARIZE = "true";
    TAPEBACK_HOTWORDS = cfg.hotwords;
    OMP_NUM_THREADS = toString cfg.threads;
  };
  exports = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") env);

  runtimePath = lib.makeBinPath [
    pkgs.ffmpeg pkgs.pulseaudio pkgs.libnotify pkgs.coreutils pkgs.util-linux
    pkgs.openssh pkgs.rsync pkgs.systemd pkgs.uv
  ];

  torchIndex = lib.optionalString worker
    "--index-strategy unsafe-best-match --extra-index-url https://download.pytorch.org/whl/cpu";

  # Pre-download the Whisper model so the first meeting does not wait for it.
  modelDownload = ''
    HF_HUB_DISABLE_XET=1 ${venv}/bin/python - <<'PY' || echo "model download failed; it will be retried on the next run"
    from huggingface_hub import snapshot_download
    snapshot_download("Systran/faster-whisper-${cfg.whisperModel}")
    print("whisper model ready")
    PY
  '';

  setupScript = pkgs.writeShellScript "tapeback-setup" ''
    set -eu
    export PATH=${runtimePath}:$PATH
    want="$(sha256sum < ${reqFile} | cut -d' ' -f1) ${py}"
    stamp=${venv}/.tapeback-stamp
    if [ -x ${venv}/bin/tapeback ] && [ "$(cat "$stamp" 2>/dev/null)" = "$want" ]; then
      echo "tapeback venv is up to date"
    else
      echo "building tapeback venv (first time takes a few minutes)"
      rm -rf ${venv}
      mkdir -p ${home}/.local/share/tapeback
      uv venv --python ${py}/bin/python3.13 ${venv}
      uv pip sync --python ${venv}/bin/python --require-hashes ${torchIndex} ${reqFile}
      echo "$want" > "$stamp"
    fi
    ${lib.optionalString worker modelDownload}
  '';

  # `tapeback ...` on the command line: same settings as the tray, safe vault path.
  tapebackCli = pkgs.writeShellScriptBin "tapeback" ''
    export PATH=${runtimePath}:$PATH
    ${exports}
    [ -x ${venv}/bin/tapeback ] || { echo "tapeback is not installed yet: run  systemctl --user start tapeback-env  (or tapeback-setup)"; exit 1; }
    exec ${venv}/bin/tapeback "$@"
  '';

  trayBin = pkgs.writeShellScriptBin "tapeback-tray" ''
    export PATH=${runtimePath}:$PATH
    ${exports}
    [ -x ${venv}/bin/python ] || { notify-send "tapeback" "Still installing. Try again in a few minutes."; exit 1; }
    # One tray at a time.
    exec flock -n "''${XDG_RUNTIME_DIR:-/tmp}/tapeback-tray.lock" ${venv}/bin/python ${./tapeback/tapeback_tray.py}
  '';

  workerBin = pkgs.writeShellScript "tapeback-worker" ''
    export PATH=${runtimePath}:$PATH
    ${exports}
    exec ${venv}/bin/python ${./tapeback/tapeback_worker.py}
  '';

  sshOpts = "-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new";

  handoffScript = pkgs.writeShellScript "tapeback-handoff" ''
    export PATH=${runtimePath}:$PATH
    set -u
    mkdir -p ${state}/outbox ${state}/inbox ${state}/incoming
    exec 9>${state}/handoff.lock
    flock -n 9 || exit 0
    shopt -s nullglob
    for f in ${state}/outbox/*.wav; do
      n="$(basename "$f")"
      ${if worker then ''
        mv "$f" ${state}/inbox/"$n"
      '' else ''
        ssh ${sshOpts} ${cfg.workerHost} "mkdir -p ${remoteInbox} .local/state/tapeback/incoming" || exit 1
        rsync -e "ssh ${sshOpts}" --partial "$f" ${cfg.workerHost}:.local/state/tapeback/incoming/"$n" || exit 1
        ssh ${sshOpts} ${cfg.workerHost} "mv .local/state/tapeback/incoming/'$n' ${remoteInbox}/'$n'" || exit 1
        rm -f "$f"
      ''}
      echo "handed off $n"
    done
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "tapeback";
    desktopName = "Tapeback";
    genericName = "Meeting recorder";
    comment = "Record a meeting; the transcript lands in Obsidian";
    exec = "tapeback-tray";
    icon = "audio-input-microphone";
    categories = [ "AudioVideo" "Audio" "Recorder" ];
    terminal = false;
  };

  setupBin = pkgs.writeShellScriptBin "tapeback-setup" ''exec ${setupScript}'';

  # Saves the Hugging Face token without it ever appearing on screen or in history.
  tokenBin = pkgs.writeShellScriptBin "tapeback-hf-token" ''
    set -eu
    umask 077
    mkdir -p ${home}/.config/tapeback
    printf 'Paste the Hugging Face token (typing is hidden), then Enter: '
    read -rs tok; echo
    case "$tok" in hf_*) ;; *) echo "That does not look like a Hugging Face token (hf_...). Nothing saved."; exit 1;; esac
    f=${home}/.config/tapeback/.env
    touch "$f"; chmod 600 "$f"
    grep -v '^TAPEBACK_HF_TOKEN=' "$f" > "$f.new" || true
    printf 'TAPEBACK_HF_TOKEN=%s\n' "$tok" >> "$f.new"
    mv "$f.new" "$f"; chmod 600 "$f"
    echo "Saved to $f. Queued recordings will be processed within 15 minutes (or run: systemctl --user start tapeback-worker)."
  '';
in
{
  options.services.tapeback = {
    enable = lib.mkEnableOption "tapeback meeting recorder";
    role = lib.mkOption {
      type = lib.types.enum [ "client" "worker" ];
      default = "client";
      description = "client: record and ship audio to the worker. worker: also transcribe.";
    };
    workerHost = lib.mkOption {
      type = lib.types.str;
      default = "nucbox";
      description = "Tailscale hostname of the worker (clients only).";
    };
    notesDir = lib.mkOption {
      type = lib.types.str;
      default = "${home}/Documents/Obsidian Sync Vault/Meetings/Inbox";
      description = "Where finished Markdown notes go (worker only). Never audio.";
    };
    whisperModel = lib.mkOption {
      type = lib.types.str;
      default = "large-v3";
    };
    threads = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = "CPU threads for transcription (worker only).";
    };
    hotwords = lib.mkOption {
      type = lib.types.str;
      default = "Tselio, Basis Nutrition, Hegemonikon, Kenai, FicaPort, Obsidian, Tailscale, Grok Bot";
      description = "Names Whisper should prefer spelling correctly.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ tapebackCli trayBin setupBin desktopItem pkgs.ffmpeg pkgs.rsync ]
      ++ lib.optional worker tokenBin;

    systemd.user.services.tapeback-env = {
      description = "Install tapeback into ~/.local/share/tapeback/venv";
      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = setupScript;
        Restart = "on-failure";
        RestartSec = "120";
        TimeoutStartSec = "infinity";
        Nice = 10;
      };
    };

    # Move finished recordings off this machine (client) or into the queue (worker).
    systemd.user.services.tapeback-handoff = {
      description = "Hand recordings to the tapeback worker";
      serviceConfig = { Type = "oneshot"; ExecStart = handoffScript; };
    };
    systemd.user.timers.tapeback-handoff = {
      description = "Retry hand-off (worker offline, laptop asleep)";
      wantedBy = [ "timers.target" ];
      timerConfig = { OnBootSec = "2min"; OnUnitActiveSec = "5min"; };
    };

    systemd.user.services.tapeback-worker = lib.mkIf worker {
      description = "Transcribe queued meetings (Whisper large-v3 + pyannote)";
      after = [ "tapeback-env.service" ];
      wants = [ "tapeback-env.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = workerBin;
        TimeoutStartSec = "infinity";
        # Polite: the nucbox is also your workstation.
        Nice = 15;
        CPUWeight = 20;
        IOSchedulingClass = "idle";
        MemoryHigh = "14G";
      };
    };
    systemd.user.paths.tapeback-worker = lib.mkIf worker {
      description = "Start the tapeback worker when a recording arrives";
      wantedBy = [ "default.target" ];
      pathConfig = {
        PathChanged = "${state}/inbox";
        MakeDirectory = true;
        Unit = "tapeback-worker.service";
      };
    };
    # Also retries recordings held back (e.g. waiting for the Hugging Face token).
    systemd.user.timers.tapeback-worker = lib.mkIf worker {
      description = "Retry the tapeback queue";
      wantedBy = [ "timers.target" ];
      timerConfig = { OnBootSec = "3min"; OnUnitActiveSec = "15min"; };
    };
  };
}
