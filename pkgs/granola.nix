# Granola (AI meeting notepad). Not packaged for Linux by Granola; this
# repackages the official macOS .dmg onto the Linux Electron runtime, following
# https://github.com/tirtha4/Granola-for-Linux (granola-linux.sh):
#   - extract app.asar, app.asar.unpacked and icons from the dmg (LZFSE → 7zz)
#   - rewrite the platform fallback so api.granola.ai sees "Windows"
#     (it answers 500 to platform=linux, which breaks sign-in)
#   - rebuild Granola's patched better-sqlite3-multiple-ciphers fork (adds
#     updateHook) from the C++ source shipped in app.asar.unpacked, against
#     the Electron headers. binding.gyp comes from the matching npm release.
# The dmg bundles Electron 44.x; we use nixpkgs' electron_44-bin (same major,
# same ABI). Bump: pkgs/update-granola.sh (nightly, local only).
{
  lib,
  stdenv,
  fetchurl,
  _7zz,
  python3,
  nodejs,
  node-gyp,
  makeWrapper,
  electron_44-bin,
  copyDesktopItems,
  makeDesktopItem,
}:

let
  electron = electron_44-bin;
  bs3Version = "12.9.0";
  bs3Npm = fetchurl {
    url = "https://registry.npmjs.org/better-sqlite3-multiple-ciphers/-/better-sqlite3-multiple-ciphers-${bs3Version}.tgz";
    hash = "sha256-rYzrLP5ofgwQZUf90oHw0gtAaIIA0E9AuxY6/R8QJgk=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "granola";
  version = "7.722.0";

  src = fetchurl {
    url = "https://dr2v7l5emb758.cloudfront.net/${finalAttrs.version}/Granola-${finalAttrs.version}-mac-universal.dmg";
    hash = "sha256-QFd06V69eewWcY8xv89UL8c96yspSdBqLRV5ysS+iVo=";
  };

  nativeBuildInputs = [
    _7zz
    python3
    nodejs
    makeWrapper
    copyDesktopItems
  ];

  dontConfigure = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    res="Granola/Granola.app/Contents/Resources"
    7zz x "$src" "$res/app.asar" "$res/app.asar.unpacked" "$res/icons" -odmg -y >/dev/null
    mv "dmg/$res" resources

    # Native modules are built for our Electron; refuse a major mismatch.
    7zz e "$src" "Granola/Granola.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist" -ofw -y >/dev/null
    dmgElectron="$(grep -A1 CFBundleVersion fw/Info.plist | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    if [ "''${dmgElectron%%.*}" != "${lib.versions.major electron.version}" ]; then
      echo "Granola bundles Electron $dmgElectron but we use ${electron.version}; switch electron_NN-bin" >&2
      exit 1
    fi
    rm -rf dmg
    runHook postUnpack
  '';

  buildPhase = ''
    runHook preBuild

    python3 - resources/app.asar <<'PYEOF'
    import sys, pathlib
    p = pathlib.Path(sys.argv[1]); data = p.read_bytes(); total = 0
    for pat in (b'?`Windows`:window.electron.platform', b'?`Windows`:process.platform'):
        rep = b'?`Windows`:`Windows`'.ljust(len(pat))
        total += data.count(pat)
        data = data.replace(pat, rep)
    if total == 0:
        sys.exit("no platform fallback found; Granola's bundle changed")
    p.write_bytes(data)
    print(f"rewrote {total} platform fallback(s)")
    PYEOF

    bs3=resources/app.asar.unpacked/node_modules/better-sqlite3-multiple-ciphers
    actual="$(node -p "require('./$bs3/package.json').version")"
    if [ "$actual" != "${bs3Version}" ]; then
      echo "better-sqlite3-multiple-ciphers is $actual, expected ${bs3Version}; bump bs3Version/hash" >&2
      exit 1
    fi
    tar xzf ${bs3Npm} package/binding.gyp
    cp package/binding.gyp "$bs3/"
    rm -rf "$bs3/build"
    export HOME="$TMPDIR"
    # nixpkgs' node-gyp wrapper forces npm_config_nodedir to its nodejs, so
    # call node-gyp.js directly and point it at the Electron headers.
    export npm_config_nodedir=${electron.headers}
    (cd "$bs3" && node ${node-gyp}/lib/node_modules/node-gyp/bin/node-gyp.js rebuild --release --nodedir=${electron.headers} --arch=x64)
    rm -rf "$bs3/build/Release/obj" "$bs3/build/Release/.deps" "$bs3/build/Release/obj.target"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/granola" "$out/bin"
    cp -r --no-preserve=mode ${electron}/libexec/electron/. "$out/lib/granola/"
    chmod +x "$out/lib/granola/electron" "$out/lib/granola/chrome_crashpad_handler" "$out/lib/granola/chrome-sandbox"
    rm -f "$out/lib/granola/resources/default_app.asar"
    cp -r resources/app.asar resources/app.asar.unpacked resources/icons "$out/lib/granola/resources/"

    install -Dm644 resources/icons/icon.png "$out/share/icons/hicolor/512x512/apps/granola.png"

    makeWrapper "$out/lib/granola/electron" "$out/bin/granola" \
      --set-default ELECTRON_OZONE_PLATFORM_HINT auto \
      --add-flags "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "granola";
      desktopName = "Granola";
      comment = "AI notepad for meetings";
      exec = "granola %U";
      icon = "granola";
      categories = [ "Office" "Utility" ];
      startupWMClass = "Granola";
      mimeTypes = [ "x-scheme-handler/granola" ];
    })
  ];

  meta = {
    description = "Granola AI meeting notepad (macOS build repackaged on Linux Electron)";
    homepage = "https://granola.ai";
    license = lib.licenses.unfree;
    mainProgram = "granola";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
