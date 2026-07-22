# User-level config managed by home-manager.
# This file is a FUNCTION called by flake.nix with the args below.
# Per-feature user configs live in sibling files and are pulled in via `imports`.

{ config, pkgs, lib, username, ... }:

{
  # ============================================================
  #  Sub-modules: each file declares part of the user-level setup.
  # ============================================================
  imports = [
    ./neovim.nix
    ./vscode.nix
    ./brightness.nix
    ./kitty.nix
    ./web-apps.nix
  ];

  # ============================================================
  #  Identity
  # ============================================================
  home.username      = username;
  home.homeDirectory = "/home/${username}";

  # Match this to system.stateVersion the first time you set up
  # home-manager. Don't change after.
  home.stateVersion = "26.05";

  # ============================================================
  #  Home-manager itself
  # ============================================================
  programs.home-manager.enable = true;

  # ============================================================
  #  Shell — bash + handy aliases
  # ============================================================
  # ============================================================
  #  mise — polyglot runtime manager (node, bun, python, etc.)
  #  Shell integration adds mise's shims dir to PATH and re-exports
  #  tool env vars on every new shell.
  # ============================================================
  programs.mise = {
    enable = true;
    enableBashIntegration = true;
  };

  # Install the official x.ai Grok CLI on first rebuild (and whenever it's absent).
  # The binary lands in ~/.grok/bin/grok, which we add to PATH via programs.bash below.
  # SuperGrok subscription auth — no API key needed (run `grok login` once).
  #
  # SHELL=/dev/null is deliberate: the installer's last step tries to append a
  # PATH line to ~/.bashrc, but on NixOS that's a symlink into the read-only Nix
  # store, so the write fails and aborts activation. Blanking SHELL makes the
  # installer skip its shell-rc rewrite (it only edits bash/zsh/fish configs) —
  # we own PATH here instead. The extra packages supply awk/sed/grep/date/etc.
  # that the install script shells out to and that aren't in the activation PATH.
  home.activation.installGrokCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.grok/bin/grok" ]; then
      # export so the env is inherited by the `bash` running the script (the
      # right side of the pipe), not just the `curl` that fetches it.
      export PATH="${lib.makeBinPath [ pkgs.curl pkgs.bash pkgs.gawk pkgs.gnused pkgs.gnugrep pkgs.coreutils ]}:$PATH"
      export SHELL=/dev/null
      ${pkgs.curl}/bin/curl -fsSL https://x.ai/cli/install.sh | ${pkgs.bash}/bin/bash
    fi
  '';

  home.sessionVariables = {
    MISE_NODE_COMPILE = "0";
  };

  programs.bash = {
    enable = true;
    # PATH goes in initExtra (→ ~/.bashrc), NOT sessionVariables (→ ~/.profile).
    # ~/.profile is read only by *login* shells; a normal terminal window is an
    # interactive non-login shell that reads ~/.bashrc. Guard against re-prepending
    # in nested shells so PATH doesn't grow unbounded.
    initExtra = ''
      case ":$PATH:" in
        *":$HOME/.grok/bin:"*) ;;
        *) export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH" ;;
      esac
    '';
    shellAliases = {
      conf    = "code ~/nixos-config";                              # open the config repo
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#gpmare";  # apply changes
      open = "xdg-open"; # open a file or URL in the default app
    };
  };

  # ============================================================
  #  Prompt — Starship
  # ============================================================
  # Two-line prompt: directory + git info on line 1, orange ❯ on line 2.
  # No username or hostname — you know who you are.
  # Prompt tuned for the light Apple Terminal kitty theme (kitty.nix).
  programs.starship = {
    enable                = true;
    enableBashIntegration = true;
    settings = {
      format = "$directory$git_branch$git_status$cmd_duration\n$character";
      add_newline = true;

      character = {
        success_symbol = "[❯](bold #007aff)";  # macOS system blue
        error_symbol   = "[❯](bold #ff3b30)";
      };

      # Blues/greys that stay readable on both light and dark kitty themes.
      directory = {
        style             = "bold #0a84ff";
        truncation_length = 3;
        truncate_to_repo  = false;
        format            = "[$path]($style) ";
      };

      git_branch = {
        symbol = " ";
        style  = "#5ac8fa";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        style  = "#8e8e93";
        format = "[$all_status$ahead_behind]($style) ";
      };

      cmd_duration = {
        min_time          = 2000;
        style             = "#8e8e93";
        format            = "[$duration]($style) ";
      };
    };
  };

  # ============================================================
  #  Git identity (so commits are attributed correctly)
  # ============================================================
  programs.git = {
    enable = true;
    settings = {
      user = {
        name  = "Gerhard";
        email = "gpmare0@gmail.com";
      };
      # Use gh as git's credential helper so `git push` to GitHub
      # works without prompting. `!` tells git "run this as a shell
      # command" — gh's `auth git-credential` reads the stored OAuth
      # token from the keyring.
      credential.helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };

  # ============================================================
  #  AI agent instructions (Claude Code + Grok)
  # ============================================================
  # One short global file. Grok loads ~/.claude/CLAUDE.md via Claude
  # compatibility, so do NOT also put a copy under ~/.grok/rules/ or
  # home AGENTS.md — that double-loads the same text every session.
  # Project-specific rules belong in each repo's AGENTS.md / CLAUDE.md.
  home.file.".claude/CLAUDE.md".source = ./agent-instructions.md;
}
