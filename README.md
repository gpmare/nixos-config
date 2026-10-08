# nixos-config

My NixOS system as a flake. KDE Plasma 6 on `x86_64-linux`, tuned for
music production (Reaper + Focusrite Scarlett Solo + Linux-native
plugins).

## Machines

| Host     | Machine                                   |
| -------- | ----------------------------------------- |
| `nucbox` | GMKtec NucBox K8 Plus mini PC (AMD 780M)  |
| `dell`   | Dell Latitude 3540 laptop (Intel)         |

Both get the same apps and settings. Only the hardware files differ.

## Layout

```
flake.nix                              inputs + one nixosConfiguration per host
hosts/
  common.nix                           shared host config (imports every module)
  nucbox/configuration.nix             mini PC only: ROCm Ollama, swap, Hermes gateway
  nucbox/hardware-configuration.nix    mini PC disks/kernel modules (auto-generated)
  dell/configuration.nix               laptop only: Intel video driver
  dell/hardware-configuration.nix      laptop disks/kernel modules (auto-generated)
modules/
  system.nix                           boot, network, locale, ssh, nix, fonts
  desktop.nix                          KDE Plasma 6 + SDDM + KRDP
  audio.nix                            PipeWire + musnix realtime audio
  dev.nix                              git + CLI tools + language runtimes
  packages.nix                         desktop + music apps
  hermes.nix / hermes-client.nix       Hermes gateway (nucbox) / desktop app + CLI
  whisper-flow.nix                     local voice dictation
  alt-codes.nix                        Windows Alt+numpad codes
  claude-desktop.nix                   Claude Desktop
  axiom.nix                            PostgreSQL 18 for Axiom
  auto-upgrade.nix                     nightly pull + update + switch
home-manager/
  gpmare.nix                           user-level entry (imports siblings)
  kitty.nix                            terminal look + Plasma default
  plasma.nix                           Plasma settings
  web-apps.nix                         Brave web-app desktop entries
  agent-instructions.md                shared Claude/Grok global rules
  brightness.nix                       Plasma DDC/CI brightness fix
  neovim.nix / vscode.nix / cursor.nix editors
Makefile                               make switch / check / update / clean
```

## Common commands

| Command       | Effect                                                      |
| ------------- | ----------------------------------------------------------- |
| `make switch` | Build + activate new config + set as boot default           |
| `make check`  | Check every host's config evaluates (no sudo)               |
| `make test`   | Build + activate temporarily (reboot reverts)               |
| `make build`  | Build only — does it evaluate?                              |
| `make update` | Bump all flake inputs (nixpkgs, home-manager, musnix, …)    |
| `make clean`  | Garbage-collect old generations to free disk                |

`make switch` builds the config named after this machine's hostname.
First time after the 2026-10 merge (both machines were still called
`gpmare`): `make switch HOST=nucbox` on the mini PC, `make switch HOST=dell`
on the laptop.

## Bootstrapping on a fresh machine

1. Install NixOS with any installer.
2. Clone this repo.
3. Create `hosts/<newhost>/` with a `configuration.nix` (copy
   `hosts/dell/configuration.nix` and strip the Dell-only bits) and the
   `hardware-configuration.nix` the installer wrote to
   `/etc/nixos/hardware-configuration.nix`
   (or generate one: `nixos-generate-config --show-hardware-config`).
   Extra LUKS devices (e.g. swap) go in its `configuration.nix`.
4. Add `<newhost> = mkHost "<newhost>";` in `flake.nix` and its model to
   the `Makefile` safety check; `git add` the new files.
5. First rebuild — pass `experimental-features` via `--option` since
   the system doesn't have flakes enabled yet:
   ```
   sudo nixos-rebuild switch --flake .#<newhost> \
     --option experimental-features "nix-command flakes"
   ```
6. From then on, just `make switch` — the hostname now matches.
