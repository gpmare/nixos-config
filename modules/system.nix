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

    # A dead IPv6 hop used to kill a transfer after a few megabytes.
    # Retry the whole NAR rather than leaving a truncated store path.
    download-attempts = 10;
    connect-timeout = 10;
  };

  # The wifi router advertises IPv6 and installs a default route, but
  # packets to cache.nixos.org and pypi.org on that route time out.
  # IPv4 to the same hosts answers in under a second. Prefer IPv4 for
  # name lookups. Tailscale's own IPv6 addresses still work.
  environment.etc."gai.conf".text = ''
    precedence ::ffff:0:0/96 100
  '';

  # pip reads this for venv installs. Retries a dropped PyPI connection.
  environment.etc."pip.conf".text = ''
    [global]
    timeout = 60
    retries = 10
  '';

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
  #  Tailscale — mesh VPN
  # ============================================================
  # Phone (Termux) and this desktop (Termius) reach SSH/RDP over the
  # tailnet. Do not port-forward 22 or 3389 on the router (KRDP note in
  # desktop.nix). After first switch: `sudo tailscale up` (browser login).
  # Termux itself is Android-only and is not in nixpkgs.
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;

  # ============================================================
  #  Power management (logind half)
  #  IdleAction=ignore: logind itself never suspends on idle.
  #  Plasma PowerDevil still can (it talks to logind separately) —
  #  see home-manager/work-awake.nix, which blocks *idle* sleep
  #  while Claude/Grok sessions are running, but drops that block
  #  when the lid closes so a laptop actually suspends in a bag.
  #  Screen blanking is fine.
  #
  #  HandleLidSwitch*: PowerDevil claims the lid via a logind
  #  inhibitor while a Plasma session is up; these are the fallback
  #  at SDDM / no graphical session. Docked stays ignore so a
  #  closed-lid clamshell (external monitor) keeps running.
  # ============================================================
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
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
