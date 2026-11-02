# Default apps for office files, PDFs, images, vector, video, audio, CAD and layout: the ArtCraft apps (pkgs/artcraft.nix),
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
    # Later wins on overlap; pdfcraft last so PDF never goes to VectorCraft.
    to "photocraft" // to "lightcraft" // to "vectorcraft" // to "filmcraft"
    // to "soundcraft" // to "cadcraft" // to "designcraft" // to "figcraft"
    // to "wordcraft" // to "gridcraft" // to "deckcraft" // to "pdfcraft";
}
