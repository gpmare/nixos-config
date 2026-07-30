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
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Binary caches. nix-community carries unfree/community builds that
    # cache.nixos.org can't redistribute (SSPL-licensed packages, etc.).
    # cache.nixos.org and its key are added by NixOS automatically.
    substituters = [
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # ============================================================
  #  Networking
  # ============================================================
  # NetworkManager handles wpa_supplicant internally; we don't need
  # to touch `networking.wireless.enable` (and on nixpkgs-unstable
  # the networkmanager module sets it itself, so explicitly setting
  # it here conflicts).
  networking.networkmanager.enable = true;
  # Intel AX200: radio power-save causes missed beacons / drops
  # (same class of instability as on Windows with this chip).
  networking.networkmanager.wifi.powersave = false;

  # iwlmvm power_scheme: 1=always-on, 2=balanced (default), 3=low-power.
  # Both modules must be set; iwlmvm alone overrides iwlwifi.
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
    options iwlmvm power_scheme=1
  '';

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
  # Plasma's Bluedevil stack owns the tray + notifications. Do NOT enable
  # blueman here — a second Bluetooth applet (leftover from Hyprland days)
  # doubles every connect/disconnect toast and leaves sticky tray items.
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = false;

  # ============================================================
  #  Remote shell
  # ============================================================
  services.openssh.enable = true;

  # ============================================================
  #  Power management — prevent idle suspend so long-running
  #  sessions (Claude, builds) aren't killed overnight.
  #  The screen may still turn off (fine); the PC will not sleep.
  # ============================================================
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
  };

  # ============================================================
  #  Nix store: automatic GC + deduplication
  # ============================================================
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 30d";
  };

  nix.settings.auto-optimise-store = true;

  # ============================================================
  #  Allow unfree packages (VSCode, Reaper, Brave, etc.)
  # ============================================================
  nixpkgs.config.allowUnfree = true;

  # ============================================================
  #  Fonts — system-wide so every app (kitty, Plasma, …)
  #  can render glyph icons.
  # ============================================================
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono   # monospace + glyph icons (kitty, prompts)
      noto-fonts                  # wide multilingual coverage
      noto-fonts-color-emoji      # colour emoji 🎸
      font-awesome                # extra UI icons
      corefonts                   # MS fonts (Arial / Times New Roman / …) for web + docs
      vista-fonts                 # MS fonts (Calibri / Cambria / …) for web + docs
    ];
    # Tell apps which font to reach for by default per category.
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };
}
