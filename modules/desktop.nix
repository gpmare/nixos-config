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

  # ============================================================
  #  Remote desktop (KRDP — control this machine from the laptop)
  # ============================================================
  # KDE's native remote-desktop server. Unlike classic VNC (which reads
  # the X11 framebuffer that Wayland no longer exposes), KRDP streams the
  # real logged-in KWin session over the RDP protocol — so Windows'
  # built-in "Remote Desktop Connection" (mstsc.exe) connects with no
  # extra client software. Enable it and set the RDP username/password in
  # System Settings -> Remote Desktop (stored per-user, so not declared
  # here). RDP is TLS-encrypted. Keep port 3389 on the LAN only — never
  # port-forward it on the router; use Tailscale if you want it remotely.
  environment.systemPackages = [ pkgs.kdePackages.krdp ];
  networking.firewall.allowedTCPPorts = [ 3389 ];

  # ============================================================
  #  External-monitor brightness (DDC/CI)
  # ============================================================
  # Desktop monitors have no OS-dimmable backlight; they accept
  # brightness commands over the video cable via DDC/CI. KDE's
  # brightness slider (Powerdevil) drives this, but it needs the i2c
  # kernel interface enabled and the user in the "i2c" group (see
  # extraGroups in hosts/gpmare/configuration.nix). DDC/CI must also be
  # turned on in each monitor's on-screen menu; run `ddcutil detect`
  # to confirm both screens are seen.
  hardware.i2c.enable = true;
}
