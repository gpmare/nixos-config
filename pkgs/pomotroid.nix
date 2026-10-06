# Pomotroid is not in nixpkgs. The official AppImage dies on NixOS with
#   Could not create default EGL display: EGL_BAD_PARAMETER
# because its bundled WebKit + bubblewrap FHS fight the host Mesa drivers.
# Package the .deb instead: autoPatchelf against nixpkgs webkitgtk_4_1/gtk3.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  copyDesktopItems,
  makeDesktopItem,
  webkitgtk_4_1,
  gtk3,
  glib,
  cairo,
  pango,
  gdk-pixbuf,
  at-spi2-atk,
  libsoup_3,
  libxkbcommon,
  wayland,
  openssl,
  libayatana-appindicator,
  zlib,
  fontconfig,
  freetype,
  harfbuzz,
  fribidi,
  expat,
  dbus,
  alsa-lib,
  libgcc,
  xorg,
  libdrm,
  mesa,
  libgbm,
  libGL,
}:

stdenv.mkDerivation rec {
  pname = "pomotroid";
  version = "1.7.1";

  src = fetchurl {
    url = "https://github.com/Splode/pomotroid/releases/download/v${version}/Pomotroid_${version}_amd64.deb";
    hash = "sha256-obVbM7O6GFc5jTCyRsa8DvJjSsnWl+FRlIsizoh9JNQ=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    glib
    cairo
    pango
    gdk-pixbuf
    at-spi2-atk
    libsoup_3
    libxkbcommon
    wayland
    openssl
    libayatana-appindicator
    zlib
    fontconfig
    freetype
    harfbuzz
    fribidi
    expat
    dbus
    alsa-lib
    libgcc
    stdenv.cc.cc.lib
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libXext
    xorg.libXfixes
    xorg.libXrender
    xorg.libxcb
    libdrm
    mesa
    libgbm
    libGL
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "pomotroid";
      desktopName = "Pomotroid";
      comment = "A beautiful Pomodoro timer";
      exec = "pomotroid";
      icon = "pomotroid";
      categories = [ "Utility" ];
      startupWMClass = "pomotroid";
    })
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share
    install -Dm755 usr/bin/pomotroid $out/bin/pomotroid
    cp -a usr/share/icons $out/share/
    runHook postInstall
  '';

  # Host WebKit is fine; DMABUF can still flake on some AMD + Wayland setups.
  preFixup = ''
    gappsWrapperArgs+=(
      --set WEBKIT_DISABLE_DMABUF_RENDERER 1
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1
    )
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
