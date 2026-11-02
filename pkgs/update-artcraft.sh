#!/usr/bin/env bash
# Bump the ArtCraft apps in pkgs/artcraft.nix to their latest GitHub releases.
# Never commits; the nightly job discards the edit before `git pull`.
# Usage: update-artcraft.sh [--check]
set -euo pipefail
check=0; [[ "${1:-}" == "--check" ]] && check=1
repo="$(cd "$(dirname "$0")/.." && pwd)"; file="$repo/pkgs/artcraft.nix"
host="${ARTCRAFT_HOST:-$(hostname)}"
backup=$(mktemp); cp "$file" "$backup"; changed=0
trap 'cp "$backup" "$file"; rm -f "$backup"; echo "artcraft: reverted"' ERR
for app in wordcraft gridcraft deckcraft; do
  new=$(curl -fsSL --retry 3 "https://api.github.com/repos/storytold/$app/releases/latest" | jq -r .tag_name | sed 's/^v//')
  [[ "$new" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "artcraft: $app odd tag ($new)"; continue; }
  cur=$(sed -nE "s/^    $app = \{ version = \"([^\"]+)\".*/\1/p" "$file")
  [[ "$new" == "$cur" || "$(printf '%s\n%s\n' "$cur" "$new" | sort -V | tail -1)" != "$new" ]] && { echo "artcraft: $app up to date ($cur)"; continue; }
  echo "artcraft: $app $cur -> $new"; (( check )) && continue
  hash=$(nix store prefetch-file --json "https://github.com/storytold/$app/releases/download/v$new/$app-$new-linux-x86_64.tar.gz" | jq -r .hash)
  [[ "$hash" == sha256-* ]] || false
  sed -i -E "s|^(    $app = \{ version = \")[^\"]+(\"; hash = \")[^\"]+|\1$new\2$hash|" "$file"; changed=1
done
if (( changed )); then
  nix build --no-link --impure --expr \
    "(builtins.getFlake \"git+file://$repo\").nixosConfigurations.$host.pkgs.callPackage $file {}"
fi
trap - ERR; rm -f "$backup"
