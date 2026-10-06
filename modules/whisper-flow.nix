# Local, zero-cloud voice dictation (whisper.cpp + ollama cleanup + ydotool).
#
# Super+Alt hold = push-to-talk; Super+Alt double-tap = toggle lock.
# CLI: whisper-flow start|stop|toggle
#
# Ollama GPU is per-host. This module defaults to CPU so a future non-AMD
# machine can import it without pulling ROCm. AMD 780M hosts set
#   services.ollama.package = pkgs.ollama-rocm;
#   services.ollama.rocmOverrideGfx = "11.0.3";
# in the host file. (`services.ollama.acceleration` was removed on
# nixos-unstable; the replacement is `package`.)

{ config, lib, pkgs, username, ... }:

let
  uid =
    if config.users.users.${username}.uid == null
    then "1000"
    else toString config.users.users.${username}.uid;

  modelDir = "$HOME/.local/share/whisper-models";
  modelFile = "ggml-base.en-q5_1.bin";
  modelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${modelFile}";

  whisper-flow = pkgs.writeShellApplication {
    name = "whisper-flow";
    runtimeInputs = with pkgs; [
      whisper-cpp
      sox
      ydotool
      xdotool
      libcanberra-gtk3
      ollama
      coreutils
      procps
      gnused
      util-linux
    ];
    text = ''
      PIDFILE=/tmp/whisper_dictation.pid
      WAV=/tmp/whisper_dictation.wav
      LOCK=/tmp/whisper_dictation.lock
      MODEL="''${HOME}/.local/share/whisper-models/${modelFile}"
      SYSTEM_PROMPT='You are an invisible dictation cleanup engine. Remove filler words like um/uh, fix punctuation, resolve self-corrections. Output ONLY final cleaned text with no chat.'

      is_recording() {
        if [[ -f "$PIDFILE" ]]; then
          local pid
          pid=$(<"$PIDFILE")
          if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
          fi
          rm -f "$PIDFILE"
        fi
        return 1
      }

      cmd_start() {
        if is_recording; then
          exit 0
        fi
        canberra-gtk-play -i button-pressed >/dev/null 2>&1 || true
        rm -f "$WAV"
        rec -q -r 16000 -c 1 -b 16 "$WAV" &
        echo "$!" > "$PIDFILE"
      }

      cmd_stop() {
        exec 9>"$LOCK"
        flock -n 9 || exit 0

        if is_recording; then
          local pid
          pid=$(<"$PIDFILE")
          kill -INT "$pid" 2>/dev/null || true
          waited=0
          while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 20 ]; do
            sleep 0.1
            waited=$((waited + 1))
          done
          kill -KILL "$pid" 2>/dev/null || true
          wait "$pid" 2>/dev/null || true
          rm -f "$PIDFILE"
        fi

        canberra-gtk-play -i button-released >/dev/null 2>&1 || true

        if [[ ! -s "$WAV" ]]; then
          exit 0
        fi
        if [[ ! -s "$MODEL" ]]; then
          echo "whisper-flow: missing model $MODEL" >&2
          exit 1
        fi

        local raw cleaned
        raw=$(whisper-cli -m "$MODEL" -f "$WAV" -nt --no-timestamps -l en 2>/dev/null || true)
        raw=$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ -z "$raw" ]]; then
          exit 0
        fi

        cleaned=$(
          printf '%s\n\n%s\n' "$SYSTEM_PROMPT" "$raw" \
            | ollama run qwen2.5:1.5b --nowordwrap 2>/dev/null || true
        )
        cleaned=$(printf '%s' "$cleaned" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ -z "$cleaned" ]]; then
          exit 0
        fi

        : "''${YDOTOOL_SOCKET:=/run/ydotoold/socket}"
        export YDOTOOL_SOCKET
        if [[ -n "''${WAYLAND_DISPLAY:-}" || -S "$YDOTOOL_SOCKET" ]]; then
          printf '%s' "$cleaned" | ydotool type --file -
        else
          xdotool type --clearmodifiers --delay 5 -- "$cleaned"
        fi
      }

      cmd_toggle() {
        if is_recording; then
          cmd_stop
        else
          cmd_start
        fi
      }

      case "''${1:-}" in
        start)  cmd_start ;;
        stop)   cmd_stop ;;
        toggle) cmd_toggle ;;
        *)
          echo "usage: whisper-flow start|stop|toggle" >&2
          exit 2
          ;;
      esac
    '';
  };

  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);

  whisper-flow-hotkey = pkgs.writeShellApplication {
    name = "whisper-flow-hotkey";
    runtimeInputs = [ python whisper-flow ];
    text = ''
      exec ${python}/bin/python3 ${../pkgs/whisper-flow-hotkey.py} "$@"
    '';
  };
in
{
  programs.ydotool.enable = true;
  hardware.uinput.enable = true;

  users.users.${username}.extraGroups = [ "ydotool" "input" ];

  services.ollama = {
    enable = true;
    # CPU default: override `package` (and maybe rocmOverrideGfx) per host.
    package = lib.mkDefault pkgs.ollama;
    loadModels = [ "qwen2.5:1.5b" ];
  };

  environment.systemPackages = [
    pkgs.whisper-cpp
    pkgs.sox
    pkgs.ydotool
    pkgs.xdotool
    pkgs.libcanberra-gtk3
    config.services.ollama.package
    whisper-flow
    whisper-flow-hotkey
  ];

  systemd.user.services.whisper-flow-models = {
    description = "Download whisper.cpp English base.en q5_1 model if missing";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.curl pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "60s";
    };
    script = ''
      set -euo pipefail
      dir="${modelDir}"
      mkdir -p "$dir"
      dest="$dir/${modelFile}"
      if [ -s "$dest" ]; then
        exit 0
      fi
      tmp="$dest.partial"
      curl -fL --retry 5 --retry-delay 2 -o "$tmp" "${modelUrl}"
      mv "$tmp" "$dest"
    '';
  };

  # System service (not --user): SupplementaryGroups=input takes effect on
  # switch without a logout. A user service inherits the login session's
  # groups, which stay stale until the next graphical login.
  systemd.services.whisper-flow-hotkey = {
    description = "Super+Alt hold/double-tap watcher for whisper-flow";
    wantedBy = [ "graphical.target" ];
    after = [ "display-manager.service" "ydotoold.service" ];
    wants = [ "ydotoold.service" ];
    path = [ whisper-flow ];
    unitConfig.StartLimitIntervalSec = "0";
    serviceConfig = {
      Type = "simple";
      User = username;
      SupplementaryGroups = [ "input" "ydotool" ];
      ExecStartPre = "${pkgs.coreutils}/bin/test -d /run/user/${uid}";
      ExecStart = "${whisper-flow-hotkey}/bin/whisper-flow-hotkey";
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = [
        "HOME=/home/${username}"
        "XDG_RUNTIME_DIR=/run/user/${uid}"
        "YDOTOOL_SOCKET=/run/ydotoold/socket"
        "WAYLAND_DISPLAY=wayland-0"
      ];
    };
  };
}
