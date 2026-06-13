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
}
