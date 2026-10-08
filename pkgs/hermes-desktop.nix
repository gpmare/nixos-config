# The upstream desktop derivation typechecks apps/desktop with `tsc -b`, and
# that project includes *.test.tsx. use-session-actions.test.tsx imports
# tests/fixtures/session-resume-active-turn.json, which nix/desktop.nix never
# copies into the renderer source. Drop the test files before tsc; they are
# not part of the shipped app. The Electron wrapper stays upstream — only the
# renderer output path in its installPhase is swapped.
{
  lib,
  pkgs,
  hermesFlake,
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  hermesPkgs = hermesFlake.packages.${system};
  npmLib = hermesPkgs.default.hermesNpmLib;

  electronVersion = hermesFlake.inputs.nixpkgs.legacyPackages.${system}.electron.version;

  # nix/desktop.nix pins the header tarball hash next to electron.version.
  headersHash =
    let
      flat = lib.replaceStrings [ "\n" ] [ " " ] (builtins.readFile (hermesFlake + "/nix/desktop.nix"));
      matched = builtins.match ".*sha256 = \"(sha256-[^\"]+)\".*" flat;
    in
    if matched == null then
      throw "hermes-desktop: electron headers hash not found in nix/desktop.nix"
    else
      builtins.head matched;

  electronHeaders = pkgs.fetchurl {
    url = "https://artifacts.electronjs.org/headers/dist/v${electronVersion}/node-v${electronVersion}-headers.tar.gz";
    sha256 = headersHash;
  };

  renderer = npmLib.buildNpmPackage {
    dirs = [
      "apps/desktop"
      "apps/shared"
    ];
    pname = "hermes-desktop-renderer";
    doCheck = true;

    postPatch = ''
      find apps/desktop -type f \( -name '*.test.ts' -o -name '*.test.tsx' \) -delete
    '';

    buildPhase = ''
      runHook preBuild

      mkdir -p apps/desktop/build

      patchShebangs .

      pushd apps/desktop
        # typecheck :3
        npm exec -- tsc -b

        # build the renderer bundle
        # vite's emptyOutDir wipes dist/ on every run
        # so it has to be first
        npm exec -- vite build

        # build the electron bundle
        node scripts/bundle-electron-main.mjs

        # Compile node-pty against Electron's actual ABI (the nixpkgs
        # `electron` we ship). Headers come from a pinned fetchurl input
        # since the sandbox has no network here, so node-gyp's
        # normal --disturl download path can't run.
        mkdir -p "$TMPDIR/electron-headers"
        tar -xzf ${electronHeaders} -C "$TMPDIR/electron-headers" --strip-components=1

        ${lib.getExe npmLib.node-gyp} rebuild \
          --directory=../../node_modules/node-pty \
          --build-from-source \
          --runtime=electron \
          --target=${electronVersion} \
          --nodedir="$TMPDIR/electron-headers" \
          --disturl="" \
          --offline

        # Target platform/arch come from stdenv.hostPlatform, not the
        # build host's own process.platform/arch.
        node scripts/stage-native-deps.mjs linux x64
      popd

      runHook postBuild
    '';

    checkPhase = ''
      runHook preCheck

      pushd apps/desktop

        npm run postbuild

        # validate staged node-pty native binary is present.
        STAGED_PTY_NODE="./dist/node_modules/node-pty/build/Release/pty.node"

        if [ ! -f "$STAGED_PTY_NODE" ]; then
          echo "FATAL: Missing staged node-pty native binary at $STAGED_PTY_NODE"
          echo "node-pty must be compiled natively"
          exit 1
        fi

      popd

      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -rn apps/desktop/dist $out/

      echo '{"schemaVersion":1,"commit":"nix-dummy-commit","branch":"nix","dirty":false,"source":"nix"}' > $out/install-stamp.json

      cp -n apps/desktop/package.json $out/
      runHook postInstall
    '';
  };
in
hermesPkgs.desktop.overrideAttrs (old: {
  installPhase =
    let
      raw = builtins.unsafeDiscardStringContext old.installPhase;
      token = lib.findFirst (s: lib.hasInfix "hermes-desktop-renderer-" s) (throw "hermes-desktop: renderer path missing from installPhase") (
        lib.splitString " " (lib.replaceStrings [ "\n" ] [ " " ] raw)
      );
      oldRenderer = lib.removeSuffix "/*" token;
      # installPhase mentions Electron, the hermes CLI, and icons as store
      # paths. Dropping all string context removes those from the sandbox;
      # keep every path except the broken renderer.
      kept = lib.filterAttrs (path: _: !lib.hasInfix "hermes-desktop-renderer" path) (
        builtins.getContext old.installPhase
      );
      swapped = lib.replaceStrings [ oldRenderer ] [ "${renderer}" ] raw;
    in
    builtins.appendContext swapped kept;
})
