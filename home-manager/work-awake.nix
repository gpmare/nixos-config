# Keep the machine awake while interactive agent sessions are running.
#
# Why: logind IdleAction is already "ignore", but Plasma PowerDevil still
# auto-suspends after ~1h of *local* keyboard/mouse idle. Phone remote-control
# of Claude Code does not count as local activity, so PowerDevil would suspend
# mid-session and kill the terminals.
#
# Fix: a user service polls for `claude` / `grok` processes and holds a
# systemd-inhibit block on sleep while any exist. When they all exit, the
# inhibitor is dropped and PowerDevil's normal idle suspend can fire again.
# The screen may still blank (fine for remote control).
#
# On mains power (or a machine with no battery, e.g. the nucbox) the block is
# held ALWAYS, agent running or not, and lid close does not suspend: the
# box stays reachable from the phone. Only on battery does the old
# behaviour apply: block only while an agent runs, and a closed lid (not
# docked) drops the block and suspends, so a laptop in a bag doesn't drain.
#
# Auto-lock: on AC (and always on the battery-less nucbox) the service sets
# kscreenlockerrc [Daemon] Autolock=false; on battery Autolock=true.
# plasma-manager does not manage kscreenlocker, so nothing fights this.
#
# Process names: the Grok Bot desktop app's process is `grok-bot`, not
# `grok`, so the old list never matched it (2026-10-11 diagnosis).

{ pkgs, ... }:

let
  work-awake = pkgs.writeShellApplication {
    name = "work-awake";
    runtimeInputs = with pkgs; [ systemd procps coreutils kdePackages.kconfig kdePackages.qttools ];
    text = ''
      set -euo pipefail

      # Processes that mean "I'm still working" (comm name, pgrep -x).
      # Add names here if you use other long-lived agent CLIs.
      WORK_PROCS=(claude grok grok-bot claude-desktop hermes)

      inhibit_pid=""
      lock_state=""

      # Auto-lock follows power source: off on AC, on on battery. The Grok
      # Bot app kills its remote-exec helper ~3-5 min after the session
      # locks, so a locked machine is unreachable (2026-10-11). Only writes
      # on change. LockOnResume is left alone (stays true).
      set_autolock() {
        [[ "$lock_state" == "$1" ]] && return 0
        kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock "$1" || return 0
        qdbus org.freedesktop.ScreenSaver /ScreenSaver configure >/dev/null 2>&1 || true
        lock_state="$1"
      }

      has_work() {
        local p
        for p in "''${WORK_PROCS[@]}"; do
          if pgrep -x "$p" >/dev/null 2>&1; then
            return 0
          fi
        done
        return 1
      }

      # logind D-Bus booleans: "b true" / "b false". No lid → false.
      logind_bool() {
        local out
        out=$(busctl get-property org.freedesktop.login1 \
          /org/freedesktop/login1 org.freedesktop.login1.Manager "$1" 2>/dev/null) || return 1
        [[ "$out" == *true* ]]
      }

      lid_closed() { logind_bool LidClosed; }

      # True on mains power, or when there is no battery at all (desktop).
      on_ac() {
        local bat=0 ps
        for ps in /sys/class/power_supply/*; do
          [[ -r "$ps/type" ]] || continue
          case "$(cat "$ps/type")" in
            Mains) [[ "$(cat "$ps/online" 2>/dev/null)" == 1 ]] && return 0 ;;
            Battery) bat=1 ;;
          esac
        done
        [[ $bat -eq 0 ]]
      }
      docked() { logind_bool Docked; }

      start_inhibit() {
        if [[ -n "$inhibit_pid" ]] && kill -0 "$inhibit_pid" 2>/dev/null; then
          return 0
        fi
        # mode=block: logind refuses suspend/hibernate until we release.
        systemd-inhibit \
          --what=sleep \
          --who=work-awake \
          --why="On AC power or active agent session" \
          --mode=block \
          sleep infinity &
        inhibit_pid=$!
      }

      stop_inhibit() {
        if [[ -n "$inhibit_pid" ]]; then
          kill "$inhibit_pid" 2>/dev/null || true
          wait "$inhibit_pid" 2>/dev/null || true
          inhibit_pid=""
        fi
      }

      cleanup() {
        stop_inhibit
      }
      trap cleanup EXIT INT TERM

      while true; do
        # Lid closed: drop the sleep block so PowerDevil/logind can
        # suspend. If nothing is docked (laptop in a bag, not clamshell),
        # request suspend ourselves — the lid event may already have been
        # denied while we held the inhibitor, and USB mice can wake the
        # machine without firing lid again.
        if on_ac; then
          set_autolock false
          start_inhibit
        elif lid_closed; then
          set_autolock true
          stop_inhibit
          if ! docked; then
            systemctl suspend || true
            sleep 8
          fi
        elif has_work; then
          set_autolock true
          start_inhibit
        else
          set_autolock true
          stop_inhibit
        fi
        sleep 2
      done
    '';
  };
in
{
  home.packages = [ work-awake ];

  systemd.user.services.work-awake = {
    Unit = {
      Description = "Inhibit sleep while Claude/Grok sessions are running";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${work-awake}/bin/work-awake";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
