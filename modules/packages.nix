# System-wide applications. Anything you want on $PATH for all users
# goes here. User-specific config lives in home-manager/gpmare.nix.

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ----- General desktop -----
    vim
    brave
    claude-code
    wget
    obsidian
    vlc                  # Universal audio/video player
    # TODO: voice-typing à la Handy. Nothing in nixpkgs gives the
    # one-line install; revisit as a follow-up (whisper-cpp + hotkey).

    # ----- Music production -----
    reaper               # DAW
    guitarix             # Guitar amp/cab simulator
    qpwgraph             # PipeWire patchbay (visual audio routing)
    pavucontrol          # Per-app audio device + volume control

    # ----- Linux-native audio plugins (LV2/VST, load inside Reaper) -----
    lsp-plugins
    calf
    x42-plugins
    surge-XT
    vital
    dragonfly-reverb
  ];
}
