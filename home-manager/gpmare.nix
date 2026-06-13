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
    ./hyprland.nix
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
  programs.bash = {
    enable = true;
    shellAliases = {
      conf    = "code ~/nixos-config";                              # open the config repo
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#gpmare";  # apply changes
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
