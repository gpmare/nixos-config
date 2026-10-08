# Nightly (midnight) sync + upgrade + switch, on every host.
#
# Each night, as the user, in ~/nixos-config:
#   1. Throw away last night's local flake.lock bump (`git checkout`), then
#      fast-forward to GitHub main over public HTTPS (no keys needed). If that
#      can't fast-forward (unpushed local commits, or local edits to the same
#      files), it is skipped and tonight's build uses the local checkout.
#   2. `nix flake update` every input except `noAutoUpdate` — a LOCAL lock
#      bump that is never committed.
# Then, as root, `nixos-rebuild switch` builds nixosConfigurations.<hostname>
# (hostname == attr: nucbox / dell). A failed build leaves the current
# generation running; check with `systemctl status nixos-upgrade`.
#
# Why this shape: two machines each bumping flake.lock nightly would make
# their lock files drift and block `git pull`. Resetting the lock first keeps
# every checkout pullable; both machines still land on (roughly) the same
# latest inputs each night. Lock changes worth keeping must be committed and
# pushed — an uncommitted flake.lock edit is discarded at midnight.
#
# Does NOT bump: pinned local drvs (Claude Desktop / Grok Bot .debs, Pomotroid
# AppImage, claude-code-manifest.json), the curl-installed Grok CLI, mise
# runtimes, Hermes Docker images, or inputs in `noAutoUpdate`.
#
# `nixos-rebuild --upgrade` is a no-op on flakes (channels only).

{ config, lib, pkgs, username, ... }:

let
  flakeDir = "/home/${username}/nixos-config";
  repoUrl  = "https://github.com/gpmare/nixos-config.git";

  # Bumped on purpose (then built), never by the nightly job:
  #   hermes-agent — pkgs/hermes-desktop.nix patches upstream's build.
  noAutoUpdate = [ "hermes-agent" ];

  # The rebuild runs as root on a repo owned by ${username}; Nix's libgit2
  # refuses that ("not owned by current user") unless the path is marked
  # safe in a git config it reads. It reads $XDG_CONFIG_HOME/git/config.
  gitSafeConfig = pkgs.writeTextDir "git/config" ''
    [safe]
    	directory = ${flakeDir}
  '';

  prep = pkgs.writeShellScript "nixos-upgrade-prep" ''
    set -u
    export PATH=${lib.makeBinPath [ config.nix.package pkgs.git pkgs.jq pkgs.coreutils pkgs.gnugrep ]}
    cd ${lib.escapeShellArg flakeDir}

    git checkout -- flake.lock || true
    if git fetch --quiet ${repoUrl} main:refs/remotes/origin/main \
       && git merge --ff-only --quiet origin/main; then
      echo "nixos-upgrade: at $(git rev-parse --short HEAD) (origin/main)"
    else
      echo "nixos-upgrade: could not fast-forward to origin/main; building local checkout"
    fi

    inputs=$(nix flake metadata --json . | jq -r '.locks.nodes.root.inputs | keys[]' \
      | grep -vxF ${lib.concatMapStringsSep " " (i: "-e ${i}") noAutoUpdate} || true)
    # shellcheck disable=SC2086
    nix flake update --flake . $inputs
  '';
in
{
  system.autoUpgrade = {
    enable = true;
    flake = flakeDir;
    # Hostname selects nixosConfigurations.${config.networking.hostName}
    # when no #attr is given. Do not put `#<attr>` in `flake`: the module
    # inlines it unquoted and bash treats `#` as a comment.
    operation = "switch";
    upgrade = false;
    dates = "00:00";
    # Catch a missed midnight when the machine was off/asleep, on next boot.
    persistent = true;
    randomizedDelaySec = "0";
    allowReboot = false;
  };

  systemd.services.nixos-upgrade = {
    # Laptop on battery: skip. A skipped Condition* still consumes the
    # Persistent trigger, so a bag-night is missed until the next midnight
    # (better than a surprise compile on wake). Desktops have no BAT* and pass.
    unitConfig.ConditionACPower = "true";
    serviceConfig = {
      TimeoutStartSec = "6h";
      Nice = 10;
    };
    environment.XDG_CONFIG_HOME = "${gitSafeConfig}";
    path = [ config.nix.package pkgs.git pkgs.util-linux ];
    preStart = ''
      ${pkgs.util-linux}/bin/runuser -u ${username} -- \
        ${pkgs.coreutils}/bin/env -u XDG_CONFIG_HOME HOME=/home/${username} USER=${username} \
        ${prep}
    '';
  };
}
