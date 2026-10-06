# Daily midnight upgrade of flake inputs + nixos-rebuild switch.
#
# Realistic scope: everything that comes from flake inputs (nixpkgs, HM,
# plasma-manager, …). A failed build leaves the current generation running.
#
# Does NOT bump: pinned local drvs (Claude Desktop / Grok Bot .debs, Pomotroid
# AppImage, claude-code-manifest.json), the curl-installed Grok CLI, mise
# runtimes, or Hermes Docker images. Those need a hash/version edit.
#
# `nixos-rebuild --upgrade` is a no-op on flakes (channels only). We run
# `nix flake update` as the user first so flake.lock is not root-owned.

{ config, lib, pkgs, username, ... }:

let
  flakeDir = "/home/${username}/nixos-config";
in
{
  system.autoUpgrade = {
    enable = true;
    flake = flakeDir;
    # Hostname selects nixosConfigurations.${hostname} when no #attr is given.
    # Do not put `#${hostname}` in `flake`: the module inlines it unquoted and
    # bash treats `#` as a comment.
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
    path = [ config.nix.package pkgs.git pkgs.util-linux ];
    preStart = ''
      ${pkgs.util-linux}/bin/runuser -u ${username} -- \
        ${pkgs.coreutils}/bin/env HOME=/home/${username} USER=${username} \
        ${config.nix.package}/bin/nix flake update --flake ${lib.escapeShellArg flakeDir}
    '';
  };
}
