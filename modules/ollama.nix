# Ollama (local LLM runtime), both hosts. CPU by default so a non-AMD machine
# can import it without pulling ROCm; hosts override `package` where a GPU helps
# (nucbox: pkgs.ollama-rocm, see hosts/nucbox/configuration.nix).
# (Split out of the retired whisper-flow module; models are per machine.)

{ config, lib, pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = lib.mkDefault pkgs.ollama;
    loadModels = [ "qwen2.5:1.5b" ];
  };

  environment.systemPackages = [
    config.services.ollama.package
    # Small audio/desktop helpers that came with the old dictation module.
    pkgs.sox
    pkgs.xdotool
    pkgs.libcanberra-gtk3
  ];
}
