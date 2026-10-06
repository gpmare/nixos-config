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
    vivaldi
    microsoft-edge
    # nixpkgs is on 2.1.287; pin Anthropic's current binary via the official
    # zstd manifest (binary is claude.zst; plain manifest.json is the ELF).
    # Bump: curl the latest manifest over pkgs/claude-code-manifest.json
    #   curl -fsSL "https://downloads.claude.ai/claude-code-releases/$(curl -fsSL https://downloads.claude.ai/claude-code-releases/latest)/manifest.zst.json" \
    #     -o pkgs/claude-code-manifest.json
    (claude-code.override {
      manifest = lib.importJSON ../pkgs/claude-code-manifest.json;
    })
    gemini-cli
    wget
    # JSON on the command line. Claude Code's hooks parse their payload and emit
    # their allow/deny decision as JSON; without jq they fell back to Python for
    # reading but had no fallback for writing, so every refusal became a
    # "non-blocking error" and the command it was meant to stop ran anyway. The
    # hooks now degrade properly on their own, but this is the fast path.
    jq
    # PDF text + raster extraction (pdftotext, pdftoppm, pdfinfo).
    # On PATH so AI agents can read a PDF directly: the built-in web fetch
    # returns unparseable binary for one, which is what stopped an agent
    # reading the Estate Duty Act. `pdftotext -layout` keeps rate tables and
    # schedules intact; `pdftoppm` is the fallback for a scan with no text
    # layer. See home-manager/agent-skill-legislation-audit.md.
    poppler-utils
    ghostscript
    qpdf
    # Debian calls this mupdf-tools. The bin output provides mutool.
    mupdf
    # eng is required by the tesseract wrapper; afr is the extra language.
    (tesseract.override { enableLanguages = [ "eng" "afr" ]; })
    # Resumable fetches when a transfer dies. `aria2c -c` continues a partial file.
    aria2
    # Obsidian app + CLI (binaries: `obsidian`, `obsidian-cli`). CLI is on PATH
    # so AI agents can read/write the vault without the GUI.
    obsidian
    # Mail client. Plain package — no HM account wiring, no policies.
    # Updates via nixpkgs (`make update` + rebuild), not the in-app updater.
    thunderbird
    libreoffice
    freecad
    vlc                   # Universal audio/video player
    # Attr is stremio-linux-shell; the desktop entry and binary are `stremio`.
    # pkgs.stremio is a removed Qt5 alias.
    stremio-linux-shell
    # WhatsApp / YouTube Music: no solid native clients on nixpkgs right now
    # (karere was glitchy; pear-desktop threw missing-package errors). Use the
    # Brave web-app launchers in home-manager/web-apps.nix instead.
    kdePackages.kate
    termius              # SSH client (GUI). Unfree; already allowed in system.nix.
    # Pomotroid: not in nixpkgs — local AppImage package under pkgs/.
    (callPackage ../pkgs/pomotroid.nix { })
    # Grok Bot: not in nixpkgs — official Linux .deb under pkgs/.
    (callPackage ../pkgs/grok-bot.nix { })

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
    # hiPrio so this env, not the bare python313 runtime, owns `python3`.
    # PDF stack is pinned in pkgs/python-pymupdf.nix (nixpkgs is older).
    (lib.hiPrio (python3.withPackages (ps:
      let
        pdf = callPackage ../pkgs/python-pymupdf.nix { };
      in
      with ps; [
        mido            # Read/write/send MIDI messages
        python-rtmidi   # Low-level MIDI I/O (hardware ports)
        pydub           # Simple audio file manipulation in scripts
        requests        # HTTP — useful for AI API calls from scripts
        pdf.pymupdf
        pdf.pymupdf-layout
        pdf.pymupdf4llm
        sympy
      ]
    )))

    # ----- AI audio tools -----
    pkgs."demucs-rs"  # Stem separator: splits any song into vocals/drums/bass/guitar
    fluidsynth        # Software MIDI synth (plays .mid files as real instruments)
    soundfont-generaluser-gs  # High-quality GM soundfont for fluidsynth
  ];
}
