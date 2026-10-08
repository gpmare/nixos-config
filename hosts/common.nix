# Shared by every host (nucbox, dell). Everything that is not tied to one
# machine's hardware lives here or in ../modules/. Each host's own file
# (hosts/<host>/configuration.nix) imports this plus its
# hardware-configuration.nix and sets only genuinely per-machine bits.

{ config, lib, pkgs, inputs, hostname, username, ... }:

{
  # ============================================================
  #  Imports
  # ============================================================
  imports = [
    ../modules/system.nix
    ../modules/desktop.nix
    ../modules/audio.nix
    ../modules/dev.nix
    ../modules/packages.nix
    ../modules/hermes-client.nix
    ../modules/whisper-flow.nix
    ../modules/alt-codes.nix
    ../modules/claude-desktop.nix
    ../modules/auto-upgrade.nix
    ../modules/axiom.nix
  ];

  # Official Claude Desktop Linux .deb (pkgs/claude-desktop.nix).
  programs.claude-desktop.enable = true;

  # ============================================================
  #  Host identity
  # ============================================================
  # `hostname` comes from flake.nix (mkHost "nucbox" / mkHost "dell") and
  # must match the nixosConfigurations attr: `make switch` and the nightly
  # auto-upgrade pick the config by the machine's hostname.
  networking.hostName = hostname;

  # Docker on every host (dev use + `docker` group below). The Hermes
  # gateway container itself is nucbox-only (modules/hermes.nix).
  virtualisation.docker.enable = true;

  # ============================================================
  #  User account
  # ============================================================
  users.users.${username} = {
    isNormalUser = true;
    description  = "Gerhard";
    # "audio" enables realtime priority via PAM (needed by musnix).
    # "i2c" lets KDE set external-monitor brightness over DDC/CI without
    # root (see hardware.i2c.enable in modules/desktop.nix).
    # "docker" is root-equivalent; needed to docker exec into Hermes.
    # "ydotool" and "input" are added by modules/whisper-flow.nix.
    # "kvm" is for Claude Desktop Cowork (needs /dev/kvm + /dev/vhost-vsock).
    # Group membership only takes effect after a full logout/reboot.
    extraGroups = [ "networkmanager" "wheel" "audio" "i2c" "docker" "kvm" ];
  };

  # ============================================================
  #  State version — read the docs before changing this.
  #  Both machines were installed on 26.05. A future host installed on a
  #  different release must set its own value in its configuration.nix.
  # ============================================================
  system.stateVersion = lib.mkDefault "26.05";
}
