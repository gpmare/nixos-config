# Graphical desktop: X11 + KDE Plasma 6, SDDM login manager,
# South-African keymap.

{ config, lib, pkgs, ... }:

{
  # ============================================================
  #  X11 server (Plasma also offers a Wayland session via SDDM)
  # ============================================================
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout  = "za";
    variant = "";
  };

  # ============================================================
  #  Display manager + desktop environment
  # ============================================================
  services.displayManager.sddm.enable    = true;
  services.desktopManager.plasma6.enable = true;

  # ============================================================
  #  Wayland (modern display protocol — replaces X11).
  #  "plasma" = the Wayland session; "plasmax11" = the X11 session.
  #  Both are still selectable at the SDDM login screen if you ever
  #  need to fall back.
  # ============================================================
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.wayland.enable = true;
}
