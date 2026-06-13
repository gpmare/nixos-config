# Thunar — a lightweight graphical file manager (your "Windows Explorer").
# Adapted from francoisrob/dotfiles. Launch it with Super+E, or from the
# app launcher (Super+R → "thunar").

{ pkgs, ... }:

{
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin     # right-click → extract / create .zip etc.
      thunar-volman             # auto-handle USB sticks / removable media
      thunar-media-tags-plugin  # show audio/video tags in file properties
    ];
  };

  # Background helpers Thunar leans on:
  services.gvfs.enable    = true;   # mount USB drives, trash, network shares
  services.tumbler.enable = true;   # generate thumbnails (image / PDF previews)

  environment.systemPackages = with pkgs; [
    file-roller   # GUI archive manager, for double-clicking .zip files
  ];
}
