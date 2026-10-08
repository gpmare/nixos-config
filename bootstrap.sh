#!/usr/bin/env bash
# One-time recovery rebuild.
#
# A prior rebuild installed an /etc/nix/nix.conf containing a TYPO'd
# nix-community public key (43 chars, one short). The running nix-daemon
# now rejects every operation with "public key is not valid", and can't
# be fixed except by a successful rebuild that regenerates nix.conf.
#
# This invocation overrides the daemon's poisoned settings for one build,
# using the CORRECT keys + caches so mongodb (unfree, only on nix-community)
# downloads from the binary cache instead of compiling from source. Once it
# activates, the regenerated nix.conf is correct and plain `rebuild` works.
set -euo pipefail

# Host = this machine's nixosConfigurations attr (nucbox / dell).
HOST="${1:-$(hostname)}"

sudo nixos-rebuild switch \
  --flake "/home/gpmare/nixos-config#${HOST}" \
  --option substituters \
    "https://cache.nixos.org https://nix-community.cachix.org https://hyprland.cachix.org" \
  --option trusted-public-keys \
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
