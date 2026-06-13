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
  ];

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
  #  User account
  # ============================================================
  users.users.${username} = {
    isNormalUser = true;
    description  = "Gerhard";
    # "audio" enables realtime priority via PAM (needed by musnix).
    extraGroups = [ "networkmanager" "wheel" "audio" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # ============================================================
  #  State version — read the docs before changing this.
  # ============================================================
  system.stateVersion = "26.05";
}
