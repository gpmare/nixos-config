# User-level config managed by home-manager.
# This file is a FUNCTION called by flake.nix with the args below.
# Per-feature user configs (Hyprland, etc.) live in sibling files
# and are pulled in via `imports`.

{ config, pkgs, username, ... }:

{
  # ============================================================
  #  Sub-modules: each file declares part of the user-level setup.
  # ============================================================
  imports = [
    ./neovim.nix
    ./vscode.nix
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

  # Force mise to install pre-built Node instead of compiling from source.
  # On NixOS the source build fails; the prebuilt binary runs via nix-ld
  # (see modules/dev.nix nix-ld.libraries).
  home.sessionVariables = {
    MISE_NODE_COMPILE = "0";
  };

  programs.bash = {
    enable = true;
    sessionVariables = {
      PATH = "$HOME/.local/bin:$PATH";
    };
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
  programs.starship = {
    enable                = true;
    enableBashIntegration = true;
    settings = {
      format = "$directory$git_branch$git_status$cmd_duration\n$character";
      add_newline = true;

      character = {
        success_symbol = "[❯](bold #ff6b00)";
        error_symbol   = "[❯](bold #cc4444)";  # turns red on non-zero exit
      };

      directory = {
        style             = "#e0c0a0";
        truncation_length = 3;
        truncate_to_repo  = false;
        format            = "[$path]($style) ";
      };

      git_branch = {
        symbol = " ";   # nerd font git icon
        style  = "#ff8533";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        style  = "#d4a040";
        format = "[$all_status$ahead_behind]($style) ";
      };

      cmd_duration = {
        min_time          = 2000;   # only show if command took > 2 s
        style             = "#808080";
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
        name  = "Gerhard";              # TODO: set to your GitHub username
        email = "gpmare0@gmail.com";
      };
      # Use gh as git's credential helper so `git push` to GitHub
      # works without prompting. `!` tells git "run this as a shell
      # command" — gh's `auth git-credential` reads the stored OAuth
      # token from the keyring.
      credential.helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };
}
