#!/usr/bin/env bash
# Bump pkgs/claude-code-manifest.json to the latest Claude Code release, safely.
#
# In plain English:
#   1. Ask Anthropic's release server which version is current.
#   2. If it's the same as ours (or older), do nothing.
#   3. Otherwise download that release's manifest over ours.
#   4. Test-build the package. If the build fails, put the old manifest back.
#
# Same rules as update-grok-bot.sh: never commits or pushes; the nightly job
# throws the edit away before the next `git pull` and re-applies it.
#
# Usage: update-claude-code.sh [--check]   (--check: only report, change nothing)
set -euo pipefail

check=0; [[ "${1:-}" == "--check" ]] && check=1
repo="$(cd "$(dirname "$0")/.." && pwd)"
file="$repo/pkgs/claude-code-manifest.json"
host="${CLAUDE_HOST:-$(hostname)}"
base=https://downloads.claude.ai/claude-code-releases

new=$(curl -fsSL --retry 3 "$base/latest" | tr -d '[:space:]')
[[ "$new" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "claude-code: odd version ($new); skipping"; exit 0; }
cur=$(jq -r .version "$file")
newest=$(printf '%s\n%s\n' "$cur" "$new" | sort -V | tail -1)
if [[ "$new" == "$cur" || "$newest" != "$new" ]]; then
  echo "claude-code: up to date ($cur; server has $new)"; exit 0
fi
echo "claude-code: $cur -> $new available"
(( check )) && exit 0

tmp=$(mktemp)
curl -fsSL --retry 3 "$base/$new/manifest.zst.json" -o "$tmp"
[[ "$(jq -r .version "$tmp")" == "$new" ]] \
  || { rm -f "$tmp"; echo "claude-code: manifest version mismatch; skipping"; exit 0; }

backup=$(mktemp); cp "$file" "$backup"
trap 'cp "$backup" "$file"; rm -f "$backup" "$tmp"; echo "claude-code: reverted to $cur"' ERR
cp "$tmp" "$file"; rm -f "$tmp"

nix build --no-link --impure --expr \
  "let p = (builtins.getFlake \"git+file://$repo\").nixosConfigurations.$host.pkgs; in p.claude-code.override { manifest = p.lib.importJSON $file; }"
trap - ERR; rm -f "$backup"
echo "claude-code: now $new (build OK)"
