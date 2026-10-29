#!/usr/bin/env bash
# Bump pkgs/granola.nix to the latest Granola macOS build, safely.
#
#   1. Ask Granola's updater feed (latest-mac.yml) for the newest version.
#   2. If it's not newer than ours, do nothing.
#   3. Otherwise prefetch the versioned .dmg, write version + hash into
#      pkgs/granola.nix, and test-build it (platform patch, better-sqlite3
#      rebuild, Electron major check). If the build fails, put the old file
#      back.
#
# Same rules as update-claude-desktop.sh: never commits or pushes; the nightly
# job throws the edit away before the next `git pull` and re-applies it.
#
# Usage: update-granola.sh [--check]   (--check: only report, change nothing)
set -euo pipefail

check=0; [[ "${1:-}" == "--check" ]] && check=1
repo="$(cd "$(dirname "$0")/.." && pwd)"
file="$repo/pkgs/granola.nix"
host="${GRANOLA_HOST:-$(hostname)}"

new=$(curl -fsSL --retry 3 https://api.granola.ai/v1/check-for-update/latest-mac.yml \
  | sed -nE 's/^version: *([0-9.]+)\s*$/\1/p' | head -1)
[[ "$new" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "granola: odd feed ($new); skipping"; exit 0; }

cur=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$file")
newest=$(printf '%s\n%s\n' "$cur" "$new" | sort -V | tail -1)
if [[ "$new" == "$cur" || "$newest" != "$new" ]]; then
  echo "granola: up to date ($cur; feed has $new)"; exit 0
fi
echo "granola: $cur -> $new available"
(( check )) && exit 0

url="https://dr2v7l5emb758.cloudfront.net/$new/Granola-$new-mac-universal.dmg"
hash=$(nix store prefetch-file --json "$url" | jq -r .hash)
[[ "$hash" == sha256-* ]] || { echo "granola: prefetch failed"; exit 1; }

backup=$(mktemp); cp "$file" "$backup"
trap 'cp "$backup" "$file"; rm -f "$backup"; echo "granola: reverted to $cur"' ERR

sed -i -E "s/^(  version = \")[^\"]+(\";)/\1$new\2/" "$file"
# The dmg hash is the `hash =` line right after the cloudfront url.
awk -v h="$hash" '/cloudfront\.net/{f=1} f && /^    hash = "/{sub(/"[^"]+"/, "\"" h "\""); f=0}1' \
  "$file" > "$file.tmp" && mv "$file.tmp" "$file"

nix build --no-link --impure --expr \
  "(builtins.getFlake \"git+file://$repo\").nixosConfigurations.$host.pkgs.callPackage $file {}"
trap - ERR; rm -f "$backup"
echo "granola: now $new (build OK)"
