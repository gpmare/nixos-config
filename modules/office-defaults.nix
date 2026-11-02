# Default apps for office files and PDFs: the ArtCraft apps (pkgs/artcraft.nix),
# set broadly on purpose so Gerhard can test them and report bugs. The MIME list
# lives in pkgs/artcraft-mime.nix (also added to each app's .desktop file).
# LibreOffice stays installed and remains under right-click > Open With.
# Note: a per-user ~/.config/mimeapps.list [Default Applications] entry beats
# these system defaults.
{ lib, ... }:
let
  mime = import ../pkgs/artcraft-mime.nix;
  to = app: lib.genAttrs mime.${app} (_: "ai.storyteller.${app}.desktop");
in
{
  xdg.mime.enable = true;
  xdg.mime.defaultApplications =
    to "wordcraft" // to "gridcraft" // to "deckcraft" // to "pdfcraft";
}
