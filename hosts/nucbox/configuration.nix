# Host: nucbox — GMKtec NucBox K8 Plus mini PC (Ryzen 7 8845HS, Radeon 780M).
# Always-on desktop: also runs the Hermes gateway container.
# Shared config: ../common.nix. Hardware: ./hardware-configuration.nix.

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix

    # Hermes Agent gateway (Docker). One gateway only: a second copy on
    # another machine would log into the same chat bots twice.
    ../../modules/hermes.nix
  ];

  # ============================================================
  #  LUKS-encrypted swap partition (root LUKS is in hardware-configuration.nix)
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
}
