# MIME types each ArtCraft app is made the default for (modules/office-defaults.nix)
# and that pkgs/artcraft.nix adds to the app's .desktop MimeType line, so KDE
# honours the default even for types upstream doesn't claim yet. Deliberately
# broad ("brute force" testing); plain text, HTML and images are left alone.
{
  wordcraft = [
    "application/msword"                                                      # doc
    "application/msword-template"                                             # dot
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" # docx
    "application/vnd.openxmlformats-officedocument.wordprocessingml.template" # dotx
    "application/vnd.ms-word.document.macroEnabled.12"                        # docm
    "application/vnd.ms-word.template.macroEnabled.12"                        # dotm
    "application/vnd.oasis.opendocument.text"                                 # odt
    "application/vnd.oasis.opendocument.text-template"                        # ott
    "application/vnd.oasis.opendocument.text-flat-xml"                        # fodt
    "application/rtf" "text/rtf"                                              # rtf
    "application/vnd.wordperfect"                                             # wpd
    "application/vnd.ms-works"                                                # wps
    "text/markdown"                                                           # md (WordCraft lists it)
  ];
  gridcraft = [
    "application/vnd.ms-excel"                                                # xls, xlt
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"       # xlsx
    "application/vnd.openxmlformats-officedocument.spreadsheetml.template"    # xltx
    "application/vnd.ms-excel.sheet.macroEnabled.12"                          # xlsm
    "application/vnd.ms-excel.sheet.binary.macroEnabled.12"                   # xlsb
    "application/vnd.ms-excel.template.macroEnabled.12"                       # xltm
    "application/vnd.oasis.opendocument.spreadsheet"                          # ods
    "application/vnd.oasis.opendocument.spreadsheet-template"                 # ots
    "application/vnd.oasis.opendocument.spreadsheet-flat-xml"                 # fods
    "text/csv"                                                                # csv
    "text/tab-separated-values"                                               # tsv
  ];
  deckcraft = [
    "application/vnd.ms-powerpoint"                                           # ppt, pps, pot
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" # pptx
    "application/vnd.openxmlformats-officedocument.presentationml.slideshow"  # ppsx
    "application/vnd.openxmlformats-officedocument.presentationml.template"   # potx
    "application/vnd.ms-powerpoint.presentation.macroEnabled.12"              # pptm
    "application/vnd.ms-powerpoint.slideshow.macroEnabled.12"                 # ppsm
    "application/vnd.ms-powerpoint.template.macroEnabled.12"                  # potm
    "application/vnd.oasis.opendocument.presentation"                         # odp
    "application/vnd.oasis.opendocument.presentation-template"                # otp
    "application/vnd.oasis.opendocument.presentation-flat-xml"                # fodp
  ];
  pdfcraft = [ "application/pdf" ];
}
