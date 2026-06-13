# Bootloader, networking, locale, time, printing, bluetooth, ssh,
# and the Nix daemon's own settings.

{ config, lib, pkgs, ... }:

{
  # ============================================================
  #  Boot loader (systemd-boot on UEFI)
  # ============================================================
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ============================================================
  #  Nix daemon: flakes + the new `nix` CLI
  # ============================================================
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ============================================================
  #  Networking
  # ============================================================
  # NetworkManager handles wpa_supplicant internally; we don't need
  # to touch `networking.wireless.enable` (and on nixpkgs-unstable
  # the networkmanager module sets it itself, so explicitly setting
  # it here conflicts).
  networking.networkmanager.enable = true;

  # ============================================================
  #  Locale + time zone
  # ============================================================
  time.timeZone      = "Africa/Johannesburg";
  i18n.defaultLocale = "en_GB.UTF-8";

  # ============================================================
  #  Printing
  # ============================================================
  services.printing.enable = true;

  # ============================================================
  #  Bluetooth
  # ============================================================
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = true;

  # ============================================================
  #  Remote shell
  # ============================================================
  services.openssh.enable = true;

  # ============================================================
  #  Allow unfree packages (VSCode, Reaper, Brave, etc.)
  # ============================================================
  nixpkgs.config.allowUnfree = true;

  # ============================================================
  #  Fonts — system-wide so every app (waybar, kitty, Plasma, …)
  #  can render glyph icons.
  # ============================================================
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
