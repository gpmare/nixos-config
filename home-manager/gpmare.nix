# User-level config managed by home-manager.
# This file is a FUNCTION called by flake.nix with the args below.
#
# Keep this minimal for now; we'll grow it when adding Hyprland,
# a shell config, editor configs, etc.

{ config, pkgs, username, ... }:

{
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
  #  Git identity (so commits are attributed correctly)
  # ============================================================
  programs.git = {
    enable    = true;
    userName  = "Gerhard";              # TODO: set to your GitHub username
    userEmail = "gpmare0@gmail.com";
  };
}
