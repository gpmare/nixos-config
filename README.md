# nixos-config

My NixOS system as a flake. KDE Plasma 6 on `x86_64-linux`, tuned for
music production (Reaper + Focusrite Scarlett Solo + Linux-native
plugins).

## Layout

```
flake.nix                              inputs + outputs
hosts/gpmare/
  configuration.nix                    entry point for this host
  hardware-configuration.nix           machine-specific (auto-generated)
modules/
  system.nix                           boot, network, locale, ssh, nix
  desktop.nix                          X11 + KDE Plasma 6 + SDDM
  audio.nix                            PipeWire + musnix realtime audio
  dev.nix                              editors + git + CLI tools
  packages.nix                         general + music apps
home-manager/
  gpmare.nix                           user-level config
Makefile                               make switch / update / clean
```

## Common commands

| Command       | Effect                                                      |
| ------------- | ----------------------------------------------------------- |
| `make switch` | Build + activate new config + set as boot default           |
| `make test`   | Build + activate temporarily (reboot reverts)               |
| `make build`  | Build only — does it evaluate?                              |
| `make update` | Bump all flake inputs (nixpkgs, home-manager, musnix, …)    |
| `make clean`  | Garbage-collect old generations to free disk                |

## Bootstrapping on a fresh machine

1. Install NixOS with any installer.
2. Clone this repo.
3. Replace `hosts/gpmare/hardware-configuration.nix` with the file
   the installer wrote to `/etc/nixos/hardware-configuration.nix`
   (or generate one: `nixos-generate-config --show-hardware-config`).
4. Adjust `boot.initrd.luks.devices` UUID in
   `hosts/gpmare/configuration.nix` to match the new disk.
5. First rebuild — pass `experimental-features` via `--option` since
   the system doesn't have flakes enabled yet:
   ```
   sudo nixos-rebuild switch --flake .#gpmare \
     --option experimental-features "nix-command flakes"
   ```
6. From then on, just `make switch` — the system config has flakes
   on, so the bare `nixos-rebuild` works.
