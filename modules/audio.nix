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

    # 128-sample quantum = ~2.7 ms one-way / ~5.3 ms roundtrip at 48 kHz.
    # Safe floor for the Scarlett Solo 1st gen (UAC1 USB protocol).
    # Raise to 256 if you hear crackles during heavy plugin sessions.
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate"        = 48000;
        "default.clock.quantum"     = 128;
        "default.clock.min-quantum" = 64;
        "default.clock.max-quantum" = 1024;
      };
    };
  };

  # ============================================================
  #  WirePlumber: make the Scarlett the default audio device
  # ============================================================
  # Without this, PipeWire picks whichever device it sees first at boot
  # (often the motherboard audio). Higher priority.session wins.
  services.pipewire.wireplumber.extraConfig."50-scarlett-default" = {
    "monitor.alsa.rules" = [
      {
        matches = [{ "node.name" = "~alsa_output.usb-Focusrite.*"; }];
        actions.update-props."priority.session" = 2000;
      }
      {
        matches = [{ "node.name" = "~alsa_input.usb-Focusrite.*"; }];
        actions.update-props."priority.session" = 2000;
      }
    ];
  };

  # ============================================================
  #  musnix: realtime priorities, audio-group setup, sysctl tweaks
  # ============================================================
  musnix.enable = true;

  # Bump USB interrupt thread priority so the Scarlett's audio packets
  # are never delayed by desktop activity (mouse, GPU, etc.).
  musnix.rtirq = {
    enable     = true;
    prioLow    = 60;
    prioHigh   = 95;
    nameList   = "usb";  # targets xhci_hcd / USB IRQ threads
  };
}
