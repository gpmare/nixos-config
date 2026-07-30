# Pomotroid is not in nixpkgs (package request closed). Ship the official
# Linux AppImage via appimageTools so it shows up in the app menu + $PATH.
{ lib, appimageTools, fetchurl }:

let
  pname = "pomotroid";
  version = "1.7.1";

  src = fetchurl {
    url = "https://github.com/Splode/pomotroid/releases/download/v${version}/Pomotroid_${version}_amd64.AppImage";
    hash = "sha256-p9GcZarpcH613lJGidvsnbNukFQemoClM7pK7gR2ImY=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/Pomotroid.desktop \
      $out/share/applications/pomotroid.desktop
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/128x128/apps/pomotroid.png \
      $out/share/icons/hicolor/128x128/apps/pomotroid.png
  '';

  meta = {
    description = "Simple and visually-pleasing Pomodoro timer";
    homepage = "https://github.com/Splode/pomotroid";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pomotroid";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
