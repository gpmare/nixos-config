# ArtCraft office apps (WordCraft, GridCraft, DeckCraft, PdfCraft): upstream Linux
# x86_64 release tarballs from github.com/storytold/<app>. Pure-Rust binaries
# that dlopen their windowing/GPU libs, so we patchelf + add those to
# LD_LIBRARY_PATH. nixpkgs has older wordcraft/gridcraft and no deckcraft.
# Versions/hashes are bumped nightly by pkgs/update-artcraft.sh (local, never committed).
{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, symlinkJoin
, alsa-lib, dbus, libGL, vulkan-loader, wayland, libxkbcommon
, libX11, libXcursor, libXi, libxcb }:
let
  apps = {
    wordcraft = { version = "0.14.0"; hash = "sha256-MBDaPTUtlSVuyaF6A5ZigKHUG6CdDr5WmvIwkti2SYc="; };
    gridcraft = { version = "0.15.0"; hash = "sha256-aBD4znOUtafN+vOYOCV7Y4Tc65+DJQJNR124le5Z2qo="; };
    deckcraft = { version = "0.14.1"; hash = "sha256-6Gx/oOy1XxpVPuQluT3P3IBrezeY8nK0Hx0f90rFwSo="; };
    pdfcraft  = { version = "0.17.0"; hash = "sha256-+YFKegr3e5Ba26HDB5yu3uU3WGeXBDz1r5UDkU9qvsU="; };
  };
  runtimeLibs = [ alsa-lib dbus libGL vulkan-loader wayland libxkbcommon
    libX11 libXcursor libXi libxcb ];
  extraMime = import ./artcraft-mime.nix;
  mk = pname: { version, hash }: stdenv.mkDerivation {
    inherit pname version;
    src = fetchurl {
      url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.tar.gz";
      inherit hash;
    };
    nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
    buildInputs = [ alsa-lib dbus stdenv.cc.cc.lib ];
    installPhase = ''
      mkdir -p $out; cp -r bin share $out/
      # Also claim the extra types we default to this app (modules/office-defaults.nix).
      d=$out/share/applications/ai.storyteller.${pname}.desktop
      sed -i 's|^MimeType=.*|&${lib.concatMapStrings (t: t + ";") (extraMime.${pname} or [ ])}|' $d
      # de-duplicate the list
      awk -F= -v OFS== '/^MimeType=/{n=split($2,a,";");o="";delete seen;for(i=1;i<=n;i++)if(a[i]!=""&&!seen[a[i]]++)o=o a[i]";";$2=o}1' $d > $d.tmp && mv $d.tmp $d
      for b in ${pname} ${pname}-cli; do
        wrapProgram $out/bin/$b --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
      done
    '';
    meta = { description = "ArtCraft ${pname}"; homepage = "https://getartcraft.com/apps/${pname}";
      license = with lib.licenses; [ mit asl20 ]; platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ]; mainProgram = pname; };
  };
in symlinkJoin {
  name = "artcraft-office";
  paths = lib.mapAttrsToList mk apps;
  passthru = lib.mapAttrs mk apps;
}
