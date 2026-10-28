# Windows Alt+numpad codes (Alt+130 → é, Alt+0233 → é) on Plasma/Wayland.
#
# A small evdev daemon grabs physical keyboards (re-scanning every second,
# so Bluetooth reconnects, USB replug and resume need no restart), forwards
# normal keys through one virtual uinput keyboard, and turns Alt+digits into
# a Compose sequence:  Compose KP_Divide KP_Multiply d d d d  (Unicode
# code point). ~/.XCompose maps those to the character. This works in every
# xkbcommon/GTK/Qt/Chromium/Electron/kitty app and does not depend on
# ydotool (which only types ASCII on a US keymap — the old root cause).
#
# Side effect: the Menu key becomes the Compose key (xkb compose:menu).
# Starts before whisper-flow-hotkey so that daemon sees Super+Alt on the
# virtual keyboard.

{ lib, pkgs, username, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);

  alt-codes = pkgs.writeShellApplication {
    name = "alt-codes";
    runtimeInputs = [ python ];
    text = ''
      exec ${python}/bin/python3 ${../pkgs/alt-codes.py} "$@"
    '';
  };

  composeFile = pkgs.runCommand "alt-codes-XCompose" { } ''
    ${alt-codes}/bin/alt-codes --compose > $out
  '';
in
{
  hardware.uinput.enable = true;
  users.users.${username}.extraGroups = [ "input" "uinput" ];
  environment.systemPackages = [ alt-codes ];

  # Compose key for X11/SDDM; Plasma Wayland reads kxkbrc (set below).
  services.xserver.xkb.options = lib.mkDefault "compose:menu";
  environment.sessionVariables.XCOMPOSEFILE = "${composeFile}";

  home-manager.users.${username} = {
    home.file.".XCompose".source = composeFile;
    home.file.".config/gtk-4.0/Compose".source = composeFile;
    programs.plasma.input.keyboard = {
      layouts = [ { layout = "za"; } ];
      options = [ "compose:menu" ];
    };
  };

  systemd.services.alt-codes = {
    description = "Windows Alt+numpad codes (evdev → Compose)";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" "whisper-flow-hotkey.service" ];
    unitConfig.StartLimitIntervalSec = "0";
    serviceConfig = {
      Type = "simple";
      User = username;
      SupplementaryGroups = [ "input" "uinput" ];
      Environment = "ALT_CODES_SYSTEM_COMPOSE=${pkgs.libx11}/share/X11/locale/en_US.UTF-8/Compose";
      ExecStart = "${alt-codes}/bin/alt-codes";
      Restart = "always";
      RestartSec = "1s";
    };
  };
}
