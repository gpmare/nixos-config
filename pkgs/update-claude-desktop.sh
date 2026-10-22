#!/usr/bin/env bash
# Bump pkgs/claude-desktop.nix to the latest Claude Desktop .deb, safely.
#
# In plain English:
#   1. Read Anthropic's official apt index (the same repo `apt` would use)
#      for amd64 and arm64, and take the highest version listed in both.
#   2. If it's the same as ours (or older), do nothing.
#   3. Otherwise write the new version and the index's SHA256 checksums
#      into pkgs/claude-desktop.nix.
#   4. Test-build the package (this downloads the .deb and checks the hash,
#      and re-applies our Cowork asar patch). If it fails, put the old file
#      back.
#
# Same rules as update-grok-bot.sh: never commits or pushes; the nightly job
# throws the edit away before the next `git pull` and re-applies it.
#
# Usage: update-claude-desktop.sh [--check]   (--check: only report, change nothing)
set -euo pipefail

check=0; [[ "${1:-}" == "--check" ]] && check=1
repo="$(cd "$(dirname "$0")/.." && pwd)"
file="$repo/pkgs/claude-desktop.nix"
host="${CLAUDE_HOST:-$(hostname)}"
apt=https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main

# "version sha256" for every claude-desktop entry in one arch's index.
index() {
  curl -fsSL --retry 3 "$apt/binary-$1/Packages" | awk '
    /^Package: /{p=$2} /^Version: /{v=$2}
    /^SHA256: /{if (p=="claude-desktop") print v, $2}'
}
amd=$(index amd64); arm=$(index arm64)
new=$(comm -12 <(cut -d" " -f1 <<<"$amd" | sort -u) <(cut -d" " -f1 <<<"$arm" | sort -u) | sort -V | tail -1)
[[ "$new" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "claude-desktop: odd index ($new); skipping"; exit 0; }

cur=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$file")
newest=$(printf '%s\n%s\n' "$cur" "$new" | sort -V | tail -1)
if [[ "$new" == "$cur" || "$newest" != "$new" ]]; then
  echo "claude-desktop: up to date ($cur; repo has $new)"; exit 0
fi
echo "claude-desktop: $cur -> $new available"
(( check )) && exit 0

sri() { nix hash convert --hash-algo sha256 --to sri "$1"; }
hamd=$(sri "$(awk -v v="$new" '$1==v{print $2; exit}' <<<"$amd")")
harm=$(sri "$(awk -v v="$new" '$1==v{print $2; exit}' <<<"$arm")")

backup=$(mktemp); cp "$file" "$backup"
trap 'cp "$backup" "$file"; rm -f "$backup"; echo "claude-desktop: reverted to $cur"' ERR

sed -i -E "s/^(  version = \")[^\"]+(\";)/\1$new\2/" "$file"
# amd64 is the first `hash =` line, arm64 the second.
awk -v a="$hamd" -v b="$harm" '/^      hash = "/{n++; sub(/"[^"]+"/, "\"" (n==1?a:b) "\"")}1' \
  "$file" > "$file.tmp" && mv "$file.tmp" "$file"

nix build --no-link --impure --expr \
  "(builtins.getFlake \"git+file://$repo\").nixosConfigurations.$host.pkgs.callPackage $file {}"
trap - ERR; rm -f "$backup"
echo "claude-desktop: now $new (build OK)"
