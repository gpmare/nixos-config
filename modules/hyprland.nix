# Hyprland — system-level wiring.
#
# This enables Hyprland as a SESSION ALONGSIDE Plasma. SDDM will show
# both at the login screen; pick whichever you want for that session.
# Plasma stays your fallback while you're learning.
#
# Why this is a *system* module:
#   programs.hyprland.enable wires the compositor into systemd, sets
#   up the XDG desktop portal (so screen-share/file-picker dialogs
#   work), and registers the SDDM session. The *user-facing* config
#   (keybinds, status bar, terminal, theming) lives in
#   home-manager/hyprland.nix because it's per-user dotfiles.

{ config, lib, pkgs, inputs, ... }:

{
  programs.hyprland = {
    enable        = true;
    package       = inputs.hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  # XDG portals: bridges between Wayland apps and the desktop. The
  # hyprland portal is pulled in by programs.hyprland.enable; we add
  # the GTK one too so file pickers in apps like VSCode / Brave look
  # right under Hyprland.
  xdg.portal = {
    enable     = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ============================================================
  #  External-monitor brightness (DDC/CI)
  # ============================================================
  # Your screens have no "backlight" the OS can dim (that's a laptop
  # thing). Instead, desktop monitors accept brightness commands over
  # the video cable via a protocol called DDC/CI. KDE's brightness
  # slider used this under the hood; under Hyprland we talk to it
  # ourselves with `ddcutil`.
  #
  # This enables the i2c kernel interface DDC/CI rides on and creates
  # an "i2c" group. The user must be in that group (see the user's
  # extraGroups in hosts/gpmare/configuration.nix) to use it without
  # root. NOTE: DDC/CI must also be enabled in each monitor's on-screen
  # menu, and it can be slow/flaky over some HDMI cables — after
  # rebooting, run `ddcutil detect` to confirm both screens are seen.
  hardware.i2c.enable = true;
}
