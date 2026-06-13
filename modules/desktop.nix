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
}
