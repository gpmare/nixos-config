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
# Lid close is not idle: if the lid is shut and the machine is not docked,
# the inhibitor is dropped and suspend is requested. Otherwise a laptop in
# a bag stays fully on (Grok/Claude almost always running) and drains.

{ pkgs, ... }:

let
  work-awake = pkgs.writeShellApplication {
    name = "work-awake";
    runtimeInputs = with pkgs; [ systemd procps coreutils ];
    text = ''
      set -euo pipefail

      # Processes that mean "I'm still working" (comm name, pgrep -x).
      # Add names here if you use other long-lived agent CLIs.
      WORK_PROCS=(claude grok)

      inhibit_pid=""

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
      docked() { logind_bool Docked; }

      start_inhibit() {
        if [[ -n "$inhibit_pid" ]] && kill -0 "$inhibit_pid" 2>/dev/null; then
          return 0
        fi
        # mode=block: logind refuses suspend/hibernate until we release.
        systemd-inhibit \
          --what=sleep \
          --who=work-awake \
          --why="Active Claude/Grok session" \
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
        if lid_closed; then
          stop_inhibit
          if ! docked; then
            systemctl suspend || true
            sleep 8
          fi
        elif has_work; then
          start_inhibit
        else
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
