# Windows Alt+numpad codes (Alt+130 → é) on Plasma/Wayland.
#
# Grabs physical keyboards, forwards other keys through a virtual uinput
# device, and types the decoded character with ydotool. Starts before
# whisper-flow-hotkey so that daemon sees Super+Alt on the virtual keyboard.

{ config, lib, pkgs, username, ... }:

let
  uid =
    if config.users.users.${username}.uid == null
    then "1000"
    else toString config.users.users.${username}.uid;

  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);

  alt-codes = pkgs.writeShellApplication {
    name = "alt-codes";
    runtimeInputs = [ python pkgs.ydotool ];
    text = ''
      exec ${python}/bin/python3 ${../pkgs/alt-codes.py} "$@"
    '';
  };
in
{
  programs.ydotool.enable = true;
  hardware.uinput.enable = true;

  # uinput: /dev/uinput is crw-rw---- root uinput (not the input group).
  users.users.${username}.extraGroups = [ "ydotool" "input" "uinput" ];

  environment.systemPackages = [ alt-codes ];

  # System service (not --user): SupplementaryGroups=input takes effect on
  # switch without a logout. A user service inherits the login session's
  # groups, which stay stale until the next graphical login.
  systemd.services.alt-codes = {
    description = "Windows Alt+numpad codes via ydotool";
    wantedBy = [ "graphical.target" ];
    after = [ "display-manager.service" "ydotoold.service" ];
    wants = [ "ydotoold.service" ];
    before = [ "whisper-flow-hotkey.service" ];
    unitConfig.StartLimitIntervalSec = "0";
    serviceConfig = {
      Type = "simple";
      User = username;
      SupplementaryGroups = [ "input" "ydotool" "uinput" ];
      ExecStartPre = "${pkgs.coreutils}/bin/test -d /run/user/${uid}";
      ExecStart = "${alt-codes}/bin/alt-codes";
      Restart = "always";
      RestartSec = "3s";
      Environment = [
        "HOME=/home/${username}"
        "XDG_RUNTIME_DIR=/run/user/${uid}"
        "YDOTOOL_SOCKET=/run/ydotoold/socket"
        "WAYLAND_DISPLAY=wayland-0"
      ];
    };
  };

  # After resume the physical event nodes are often new paths; the daemon
  # rescans every 5s, but restarting immediately re-grabs without a gap.
  systemd.services.alt-codes-restart-on-resume = {
    description = "Re-grab keyboards for alt-codes after sleep";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart alt-codes.service";
    };
  };
}
