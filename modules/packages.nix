# System-wide applications. Anything you want on $PATH for all users
# goes here. User-specific config lives in home-manager/gpmare.nix.

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ----- General desktop -----
    vim
    tmux                  # Terminal multiplexer — sessions survive disconnects/restarts
    kitty                 # Default terminal (look configured in home-manager/kitty.nix)
    brave
    microsoft-edge
    claude-code
    gemini-cli
    wget
    # Obsidian app + CLI (binaries: `obsidian`, `obsidian-cli`). CLI is on PATH
    # so AI agents can read/write the vault without the GUI.
    obsidian
    # Mail client. Plain package — no HM account wiring, no policies.
    # Updates via nixpkgs (`make update` + rebuild), not the in-app updater.
    thunderbird
    libreoffice
    freecad
    vlc                   # Universal audio/video player
    # WhatsApp / YouTube Music: no solid native clients on nixpkgs right now
    # (karere was glitchy; pear-desktop threw missing-package errors). Use the
    # Brave web-app launchers in home-manager/web-apps.nix instead.
    kdePackages.kate
    # Pomotroid: not in nixpkgs — local AppImage package under pkgs/.
    (callPackage ../pkgs/pomotroid.nix { })
    # TODO: voice-typing à la Handy. Nothing in nixpkgs gives the
    # one-line install; revisit as a follow-up (whisper-cpp + hotkey).

    # ----- Music production -----
    # Wrap reaper so it loads PipeWire's JACK compat libs, not a real JACK server.
    # Equivalent to running `pw-jack reaper` but works from launchers and .desktop files too.
    (symlinkJoin {
      name = "reaper";
      paths = [ reaper ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/reaper \
          --prefix LD_LIBRARY_PATH : "${pipewire.jack}/lib" \
          --prefix LV2_PATH : "/run/current-system/sw/lib/lv2" \
          --prefix LADSPA_PATH : "/run/current-system/sw/lib/ladspa"
      '';
    })
    guitarix             # Guitar amp/cab simulator
    qpwgraph             # PipeWire patchbay (visual audio routing)
    pavucontrol          # Per-app audio device + volume control

    # ----- Linux-native audio plugins (LV2/VST, load inside Reaper) -----
    lsp-plugins
    calf
    x42-plugins
    surge-xt
    vital
    dragonfly-reverb

    # ----- Reaper scripting -----
    # Python for ReaScript: lets you automate Reaper with Python code.
    # After rebuild, point Reaper at this binary:
    #   Options > Preferences > Plug-ins > ReaScript > Python path:
    #   /run/current-system/sw/bin/python3
    (python3.withPackages (ps: with ps; [
      mido            # Read/write/send MIDI messages
      python-rtmidi   # Low-level MIDI I/O (hardware ports)
      pydub           # Simple audio file manipulation in scripts
      requests        # HTTP — useful for AI API calls from scripts
    ]))

    # ----- AI audio tools -----
    pkgs."demucs-rs"  # Stem separator: splits any song into vocals/drums/bass/guitar
    fluidsynth        # Software MIDI synth (plays .mid files as real instruments)
    soundfont-generaluser-gs  # High-quality GM soundfont for fluidsynth
  ];
}
