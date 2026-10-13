#!/usr/bin/env bash
# Bump pkgs/grok-bot.nix to the latest stable Grok Bot release, safely.
#
# In plain English:
#   1. Ask Grok Bot's update server which version is current (x64 + arm64).
#   2. If it's the same as ours, do nothing.
#   3. Otherwise download both .deb files, work out their checksums, and
#      write the new version / buildId / checksums into pkgs/grok-bot.nix.
#   4. Test-build the package. If the build fails, put the old file back,
#      so the machine keeps the Grok Bot it already had.
#
# It never commits or pushes. The nightly job runs it on each machine and the
# change stays a local, uncommitted edit (like flake.lock); the job throws it
# away before the next night's `git pull`, then re-applies it. To keep a bump
# permanently, commit and push it by hand.
#
# Usage: update-grok-bot.sh [--check]   (--check: only report, change nothing)
# Needs: curl jq nix git sed (run from anywhere; finds the repo itself).
set -euo pipefail

check=0; [[ "${1:-}" == "--check" ]] && check=1
repo="$(cd "$(dirname "$0")/.." && pwd)"
file="$repo/pkgs/grok-bot.nix"
host="${GROK_BOT_HOST:-$(hostname)}"
api=https://api2.cursor.sh/updates/api/download/stable

x64=$(curl -fsSL --retry 3 "$api/linux-x64/sand")
arm=$(curl -fsSL --retry 3 "$api/linux-arm64/sand")
new=$(jq -r .version <<<"$x64")
sha=$(jq -r .commitSha <<<"$x64")
[[ "$new" == "$(jq -r .version <<<"$arm")" && "$sha" == "$(jq -r .commitSha <<<"$arm")" ]] \
  || { echo "grok-bot: x64/arm64 manifests disagree; skipping"; exit 0; }
[[ "$new" =~ ^[0-9]+(\.[0-9]+)+$ && "$sha" =~ ^[0-9a-f]{40}$ ]] \
  || { echo "grok-bot: odd manifest ($new $sha); skipping"; exit 0; }

cur=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$file")
newest=$(printf '%s\n%s\n' "$cur" "$new" | sort -V | tail -1)
if [[ "$new" == "$cur" || "$newest" != "$new" ]]; then
  echo "grok-bot: up to date ($cur; server has $new)"; exit 0
fi
echo "grok-bot: $cur -> $new available"
(( check )) && exit 0

sri() { nix hash convert --hash-algo sha256 --to sri "$(nix-prefetch-url --type sha256 "$1")"; }
hx64=$(sri "$(jq -r .debUrl <<<"$x64")")
harm=$(sri "$(jq -r .debUrl <<<"$arm")")

backup=$(mktemp); cp "$file" "$backup"
restore() { cp "$backup" "$file"; echo "grok-bot: reverted to $cur"; }
trap 'restore; rm -f "$backup"' ERR

sed -i -E \
  -e "s/^(  buildId = \")[0-9a-f]+(\";)/\1$sha\2/" \
  -e "s/^(  version = \")[^\"]+(\";)/\1$new\2/" "$file"
# The x64 hash is the first `hash =` line, arm64 the second.
awk -v a="$hx64" -v b="$harm" '/^      hash = "/{n++; sub(/"[^"]+"/, "\"" (n==1?a:b) "\"")}1' \
  "$file" > "$file.tmp" && mv "$file.tmp" "$file"

nix build --no-link --impure --expr \
  "(builtins.getFlake \"git+file://$repo\").nixosConfigurations.$host.pkgs.callPackage $file {}"
trap - ERR; rm -f "$backup"
echo "grok-bot: now $new (build OK)"
