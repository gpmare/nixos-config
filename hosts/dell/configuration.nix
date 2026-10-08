# Host: dell — Dell Latitude 3540 laptop (Intel Core i7-1355U, Iris Xe).
# Shared config: ../common.nix. Hardware: ./hardware-configuration.nix
# (root LUKS is declared there; this laptop has no swap partition).

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  # ============================================================
  #  Intel graphics — hardware video decode (VA-API) for browsers/players.
  # ============================================================
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # Ollama (whisper-flow dictation clean-up) stays on the CPU default from
  # modules/whisper-flow.nix — no ROCm/AMD GPU here.

  # Goodix fingerprint reader (27c6:63cc) is present but not set up.
  # To try it: services.fprintd.enable = true; then enrol in System Settings.
}
