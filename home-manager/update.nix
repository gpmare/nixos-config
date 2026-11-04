# `update`: run every update by hand, now, on whichever machine you type it
# (nucbox or dell). Mirrors the nightly job in modules/auto-upgrade.nix, then
# switches with `make switch` (host = this machine's hostname).
{ pkgs, ... }:

let
  update = pkgs.writeShellScriptBin "update" ''
    set -u
    cd "$HOME/nixos-config" || { echo "update: ~/nixos-config not found"; exit 1; }
    host=$(hostname)
    say() { printf '\n==> %s\n' "$*"; }

    # 1. Drop the local-only version bumps (they are re-made below), then pull.
    say "Pulling the latest config from GitHub"
    git checkout -- flake.lock pkgs/grok-bot.nix pkgs/claude-code-manifest.json \
      pkgs/claude-desktop.nix pkgs/granola.nix pkgs/artcraft.nix 2>/dev/null || true
    if ! git pull --ff-only; then
      echo "Fast-forward failed; trying a rebase with your local changes set aside."
      if ! git pull --rebase --autostash; then
        echo
        echo "update: STOPPED. Your local changes clash with GitHub's version."
        echo "Nothing was installed. Fix it with 'git status' (or ask Jeffrey)."
        exit 1
      fi
    fi

    # 2. Bump flake inputs (same list as the nightly job; pinned ones are skipped).
    say "Updating flake inputs"
    inputs=$(nix flake metadata --json . | ${pkgs.jq}/bin/jq -r '.locks.nodes.root.inputs | keys[]' \
      | grep -vx -e hermes-agent -e nixpkgs-musescore || true)
    # shellcheck disable=SC2086
    nix flake update --flake . $inputs || { echo "update: flake update failed"; exit 1; }

    # 3. App updaters (each keeps a new version only if it builds).
    say "Grok Bot";       GROK_BOT_HOST=$host bash ./pkgs/update-grok-bot.sh       || echo "Grok Bot: kept current version"
    say "Claude Code";    CLAUDE_HOST=$host   bash ./pkgs/update-claude-code.sh    || echo "Claude Code: kept current version"
    say "Claude Desktop"; CLAUDE_HOST=$host   bash ./pkgs/update-claude-desktop.sh || echo "Claude Desktop: kept current version"
    say "Granola";        GRANOLA_HOST=$host  bash ./pkgs/update-granola.sh        || echo "Granola: kept current version"
    say "Craft apps";     ARTCRAFT_HOST=$host bash ./pkgs/update-artcraft.sh       || echo "Craft apps: kept current versions"

    # 4. Build and switch to it.
    say "Installing (make switch for $host)"
    make switch && say "All up to date on $host."
  '';
in
{
  home.packages = [ update ];
}
