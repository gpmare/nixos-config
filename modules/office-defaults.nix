# Default apps for office files and PDFs: the ArtCraft apps (pkgs/artcraft.nix).
# LibreOffice stays installed and remains under right-click > Open With.
# Note: a per-user ~/.config/mimeapps.list [Default Applications] entry beats
# these system defaults.
{ lib, ... }:
let
  word = "ai.storyteller.wordcraft.desktop";
  grid = "ai.storyteller.gridcraft.desktop";
  deck = "ai.storyteller.deckcraft.desktop";
  pdf  = "ai.storyteller.pdfcraft.desktop";
  to = app: types: lib.genAttrs types (_: app);
in
{
  xdg.mime.enable = true;
  xdg.mime.defaultApplications =
    to word [
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" # docx
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
      "application/vnd.ms-word.document.macroEnabled.12"
      "application/msword"                                                      # doc
      "application/vnd.oasis.opendocument.text"                                 # odt
      "application/rtf" "text/rtf"
    ]
    // to grid [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"       # xlsx
      "application/vnd.ms-excel.sheet.macroEnabled.12"
      "application/vnd.ms-excel"                                                # xls
      "application/vnd.oasis.opendocument.spreadsheet"                          # ods
      "text/csv"
    ]
    // to deck [
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" # pptx
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
      "application/vnd.ms-powerpoint"                                           # ppt
      "application/vnd.oasis.opendocument.presentation"                         # odp
    ]
    // to pdf [ "application/pdf" ];
}
