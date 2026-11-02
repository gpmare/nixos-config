# MIME types each ArtCraft app is made the default for (modules/office-defaults.nix)
# and that pkgs/artcraft.nix adds to the app's .desktop MimeType line, so KDE
# honours the default even for types upstream doesn't claim yet. Deliberately
# broad ("brute force" testing); plain text, HTML, Markdown-beyond-WordCraft and dirs are left alone.
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
  # Rest of the suite (Gerhard: "let them be my defaults"). EffectCraft has no
  # registered MIME type upstream (.ecproj / Lottie .json), so nothing maps to it.
  photocraft = [ "image/png" "image/jpeg" "image/gif" "image/webp" "image/bmp" "image/tiff" "image/avif" "image/heic" "image/heif" "image/qoi" "image/x-tga" "image/x-icon" "image/vnd.microsoft.icon" "image/x-portable-anymap" "image/x-portable-bitmap" "image/x-portable-graymap" "image/x-portable-pixmap" "image/x-exr" "image/vnd.radiance" "image/openraster" "image/vnd.adobe.photoshop" "image/x-psd" "image/x-psb" "image/x-paintnet" "image/x-xcf" "application/x-krita" "application/x-photocraft" ];
  lightcraft = [ "image/x-adobe-dng" "image/x-sony-arw" "image/x-canon-cr2" "image/x-canon-cr3" "image/x-nikon-nef" "image/x-fuji-raf" "image/x-olympus-orf" "image/x-panasonic-rw2" "image/x-panasonic-rw" "image/x-pentax-pef" ];
  vectorcraft = [ "image/svg+xml" "image/svg+xml-compressed" "application/illustrator" "application/x-ai-template" "image/x-eps" "image/emf" "image/wmf" "application/x-affinity" "application/x-vectorcraft" "application/x-vectorcraft-template" ];
  filmcraft = [ "video/mp4" "video/x-m4v" "video/quicktime" "video/x-matroska" "video/webm" "video/vnd.avi" "video/x-msvideo" "application/mxf" "video/mp2t" "video/mpeg" "video/3gpp" "video/ogg" "video/x-flv" "video/x-ms-wmv" "application/x-filmcraft" ];
  soundcraft = [ "audio/x-wav" "audio/wav" "audio/vnd.wave" "audio/x-aiff" "audio/aiff" "audio/flac" "audio/x-flac" "audio/mpeg" "audio/midi" "audio/x-midi" "audio/ogg" "audio/x-vorbis+ogg" "audio/x-opus+ogg" "audio/mp4" "audio/aac" "audio/x-m4a" "application/x-soundcraft-session" ];
  cadcraft = [ "image/vnd.dxf" "image/vnd.dwg" "application/x-dxf" "application/acad" "model/step" "model/iges" "model/stl" ];
  designcraft = [ "application/vnd.adobe.indesign-idml-package" "application/x-scribus" "application/vnd.scribus" "application/x-designcraft" ];
  figcraft = [ "application/x-figcraft" "application/x-sketch" "x-scheme-handler/figcraft" ];
}
