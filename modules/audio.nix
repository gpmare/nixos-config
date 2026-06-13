# PipeWire (replacing PulseAudio) + musnix for realtime audio.
# Tuned for tracking vocals + guitar through the Focusrite Scarlett Solo.

{ config, lib, pkgs, ... }:

{
  # PulseAudio off — PipeWire provides the pulse API.
  services.pulseaudio.enable = false;
  security.rtkit.enable      = true;

  # ============================================================
  #  PipeWire
  # ============================================================
  services.pipewire = {
    enable             = true;
    alsa.enable        = true;
    alsa.support32Bit  = true;
    pulse.enable       = true;
    jack.enable        = true;

    # ~5.3 ms latency at 48 kHz / 256-sample quantum.
    # Lower if your machine handles it; raise if you hear crackles.
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate"        = 48000;
        "default.clock.quantum"     = 256;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 1024;
      };
    };
  };

  # ============================================================
  #  musnix: realtime priorities, audio-group setup, sysctl tweaks
  # ============================================================
  musnix.enable = true;
}
