# Per-host entry point for the "gpmare" machine.
# Pulls in hardware config + every shared module under ../../modules/.

{ config, lib, pkgs, inputs, hostname, username, ... }:

{
  # ============================================================
  #  Imports
  # ============================================================
  imports = [
    ./hardware-configuration.nix

    ../../modules/system.nix
    ../../modules/desktop.nix
    ../../modules/audio.nix
    ../../modules/dev.nix
    ../../modules/packages.nix
    ../../modules/hermes.nix
    ../../modules/whisper-flow.nix
    ../../modules/alt-codes.nix
    ../../modules/claude-desktop.nix
    ../../modules/auto-upgrade.nix
  ];

  # Official Claude Desktop Linux .deb (pkgs/claude-desktop.nix).
  programs.claude-desktop.enable = true;

  # ============================================================
  #  Host identity
  # ============================================================
  networking.hostName = hostname;

  # ============================================================
  #  LUKS-encrypted root partition
  # ============================================================
  boot.initrd.luks.devices."luks-5f8e2b15-11a6-4511-851c-2110170d173a".device =
    "/dev/disk/by-uuid/5f8e2b15-11a6-4511-851c-2110170d173a";

  # ============================================================
  #  Ollama GPU — AMD 780M (Phoenix / gfx1103)
  # ============================================================
  # whisper-flow.nix enables ollama on CPU by default. This host has a
  # Radeon 780M that ROCm does not detect as a supported gfx, so override
  # the LLVM target. Do not set nixpkgs.config.rocmSupport (rebuilds the
  # world); pkgs.ollama-rocm is the prebuilt attr.
  services.ollama.package = pkgs.ollama-rocm;
  services.ollama.rocmOverrideGfx = "11.0.3";

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
  # ============================================================
  system.stateVersion = "26.05";
}
