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

  # Battery care: this laptop is usually plugged in, so keeping it at 100%
  # wears the battery out faster. We tell the Dell firmware to use its
  # "Custom" charging mode: start charging below 75%, stop at 80%.
  # The service runs at boot and again after waking from sleep.
  # Dell refuses an end value that is not above the start value, so we
  # write the end first (raising it), then the start, then the mode.
  systemd.services.battery-charge-limit = {
    description = "Cap Dell battery charge at 80% (Custom 75-80)";
    wantedBy = [ "multi-user.target" "post-resume.target" ];
    after = [ "multi-user.target" "post-resume.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      b=/sys/class/power_supply/BAT0
      [ -e $b/charge_control_end_threshold ] || exit 0
      echo 80 > $b/charge_control_end_threshold
      echo 75 > $b/charge_control_start_threshold
      echo Custom > $b/charge_types
    '';
  };

  # Before a trip: `battery-full` charges to 100% (until reboot/resume),
  # `battery-care` goes back to the 75-80% limit.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "battery-full" "echo Standard | sudo tee /sys/class/power_supply/BAT0/charge_types")
    (pkgs.writeShellScriptBin "battery-care" "sudo systemctl restart battery-charge-limit && cat /sys/class/power_supply/BAT0/charge_types")
  ];
}
