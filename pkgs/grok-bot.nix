# Official Grok Bot Linux .deb. Not in nixpkgs.
# Product: https://x.ai/bot  CDN: downloads.cursor.com
#
# Bump: poll the stable manifest, then update version / buildId / hashes.
#   curl -fsSL https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand
#   curl -fsSL https://api2.cursor.sh/updates/api/download/stable/linux-arm64/sand
# Prefetch each debUrl, paste the SRI into sources.<system>.hash.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  addDriverRunpath,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libayatana-appindicator,
  libdrm,
  libgbm,
  libGL,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libva,
  libxkbcommon,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
  wayland,
  xdg-utils,
}:

let
  # Shared across arches; the arch segment of the URL is per-source below.
  buildId = "33103062f95061ccf9c81c5b365d37ab152c3b66";

  sources = {
    x86_64-linux = {
      arch = "x64";
      debArch = "amd64";
      hash = "sha256-sr6BBtKz6uB9mD1fHKd7ZXrM3mZtxEDbKkCUIez/M1k=";
    };
    aarch64-linux = {
      arch = "arm64";
      debArch = "arm64";
      hash = "sha256-P4X74ro8HRIqoW+L5nIHa8GRRuB+nUMfN6k7hfp1qT8=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "grok-bot is not packaged for ${stdenv.hostPlatform.system}");

  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libayatana-appindicator
    libdrm
    libgbm
    libGL
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libva
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    vulkan-loader
    wayland
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "grok-bot";
  version = "0.68.1";

  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${buildId}/linux/${source.arch}/grok-bot_${finalAttrs.version}_${source.debArch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  # Shared libraries Chromium dlopen()s rather than linking, so
  # autoPatchelfHook cannot discover them on its own.
  runtimeDependencies = [
    libglvnd
    libGL
    libgbm
    libdrm
    vulkan-loader
    wayland
    libxkbcommon
    libpulseaudio
    libsecret
    libnotify
    (lib.getLib systemd)
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar --extract --file - --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/grok-bot"
    cp -a "opt/Grok Bot/." "$out/share/grok-bot/"

    # chrome-sandbox needs to be setuid root, which the Nix store cannot
    # express. Chromium falls back to the user-namespace sandbox (on by
    # default on NixOS).
    rm -f "$out/share/grok-bot/chrome-sandbox"

    mkdir -p "$out/share"
    cp -a usr/share/applications usr/share/icons "$out/share/"

    substituteInPlace "$out/share/applications/grok-bot.desktop" \
      --replace-fail "Exec=grok-bot %U" "Exec=$out/bin/grok-bot %U"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
      --set-default ELECTRON_OZONE_PLATFORM_HINT auto
      --set-default CHROME_DESKTOP grok-bot.desktop
      --set FONTCONFIG_NO_CHECK_CACHE_VERSION 1
      --prefix VK_ADD_DRIVER_FILES : ${addDriverRunpath.driverLink}/share/vulkan/icd.d
      # Upstream's Electron crash-loops every sandbox:true renderer (the
      # <webview> that shows the agent's box) with
      # FATAL:platform_shared_memory_region_posix.cc. They already launch
      # the main renderer / GPU / utilities unsandboxed; this flag only
      # covers the remaining webview. Drop it if upstream fixes shm.
      --add-flags --no-sandbox
    )
  '';

  postFixup = ''
    makeWrapper "$out/share/grok-bot/grok-bot" "$out/bin/grok-bot" \
      "''${gappsWrapperArgs[@]}"
    # Historical binary name used by sand:// login redirects.
    ln -s grok-bot "$out/bin/sand"
  '';

  passthru = {
    inherit sources buildId;
  };

  meta = {
    description = "Grok Bot desktop agent";
    homepage = "https://x.ai/bot";
    license = lib.licenses.unfree;
    mainProgram = "grok-bot";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
  };
})
