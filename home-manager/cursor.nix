# Cursor — AI IDE (point/click browser editor, agent, voice into prompts).
#
# We install the FHS build so marketplace extensions and their native
# binaries work like on a normal Linux distro. The plain `code-cursor`
# package is more "Nix pure" but regularly breaks extension installs;
# FHS is the low-interruption choice.
#
# Version updates come from `make update` + rebuild (nixpkgs), NOT from
# Cursor's in-app updater — which cannot rewrite the Nix store and only
# nags. An activation step forces update.mode off without overwriting
# the rest of your GUI settings.

{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.code-cursor-fhs ];

  # Merge only the Nix-required keys into settings.json. Do NOT own the
  # whole file — Cursor writes themes, keybindings prefs, agent state, etc.
  # there and a full HM overwrite would stomp them on every rebuild.
  home.activation.cursorDisableSelfUpdate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf="$HOME/.config/Cursor/User/settings.json"
    mkdir -p "$(dirname "$conf")"
    if [ ! -f "$conf" ]; then
      printf '%s\n' '{"update.mode":"none","update.showReleaseNotes":false}' > "$conf"
    else
      ${pkgs.jq}/bin/jq \
        '. + {"update.mode":"none","update.showReleaseNotes":false}' \
        "$conf" > "$conf.tmp" \
        && mv "$conf.tmp" "$conf"
    fi
  '';
}
