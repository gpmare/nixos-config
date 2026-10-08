# Hermes Agent (Nous) client apps, on every host. Official flake, not in
# nixpkgs (flake input `hermes-agent`).
#   hermes-desktop   Electron app (Plasma launcher: "Hermes")
#   hermes           CLI; `hermes --tui` for the terminal UI
# Desktop → Settings → Gateway → Remote gateway to attach to the always-on
# gateway on nucbox (modules/hermes.nix).
#
# The local `hermes` CLI is its own runtime and uses ~/.hermes. On nucbox
# that same folder is the gateway container's data, so there prefer
# `docker exec -it hermes hermes …` over the bare CLI.
#
# hermes-agent is excluded from the nightly flake update
# (modules/auto-upgrade.nix): pkgs/hermes-desktop.nix patches upstream's
# build, so bump it on purpose (`nix flake update hermes-agent`) and build.

{ pkgs, inputs, ... }:

let
  hermesPkgs = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system};
  # Upstream `desktop` fails `tsc` on a test fixture the Nix source omits.
  hermesDesktop = pkgs.callPackage ../pkgs/hermes-desktop.nix {
    hermesFlake = inputs.hermes-agent;
  };
in
{
  environment.systemPackages = [
    hermesDesktop
    hermesPkgs.default
  ];
}
