# External-monitor brightness reliability for KDE Plasma (DDC/CI).
#
# Background: Plasma's PowerDevil controls the Dell's brightness directly
# over DDC/CI (it links libddcutil). The hardware works — `ddcutil setvcp`
# succeeds instantly. The problem is only at LOGIN: PowerDevil does a
# one-shot "restore saved brightness" write while the i2c bus is still busy
# and the monitor's DDC is barely awake. That write fails a few times
# (ddcutil error -3023), PowerDevil gives up for the whole session, and the
# brightness slider + system-tray button disappear.
#
# Two layers fix it (see the /loop of diagnosis in git history if curious):
#   1. ddcutilrc  — tell libddcutil to be more patient (longer per-command
#                   sleeps, more retries) so the login-time write is more
#                   likely to ride out the busy bus on its own.
#   2. restart    — once the session has settled (~30s) and the bus is quiet,
#                   restart PowerDevil so it re-probes the Dell cleanly. This
#                   is the guaranteed fix; the ddcutilrc above may make it a
#                   no-op, but the restart is what we proved always works.

{ pkgs, ... }:

{
  # --- Layer 1: make libddcutil patient -------------------------------
  # PowerDevil reads this file via libddcutil. sleep-multiplier scales the
  # mandatory pauses in the DDC protocol; maxtries raises the internal retry
  # count. Costs a few extra milliseconds per brightness change — unnoticeable.
  xdg.configFile."ddcutil/ddcutilrc".text = ''
    [libddcutil]
    options = --sleep-multiplier 3 --maxtries 15,15,15
    [ddcutil]
    options = --sleep-multiplier 3 --maxtries 15,15,15
  '';

  # --- Layer 2: re-kick PowerDevil once the session is quiet ----------
  systemd.user.services.powerdevil-ddc-fix = {
    Unit = {
      Description = "Restart PowerDevil after login so DDC/CI brightness re-probes on a quiet i2c bus";
      After = [ "plasma-powerdevil.service" "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      # Wait for the desktop + monitor DDC to fully wake before re-probing.
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 30";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user restart plasma-powerdevil.service";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
