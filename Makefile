# Shortcut commands. Run `make <target>` from anywhere in the repo.
#
# HOST is which nixosConfiguration to build (matches flake.nix).
# FLAKE is where the flake lives (`.` = current dir).

HOST  ?= gpmare
FLAKE ?= .

# Build + activate the new config now AND set it as the boot default.
switch:
	sudo nixos-rebuild --extra-experimental-features "nix-command flakes" switch --flake $(FLAKE)#$(HOST)

# Build only — useful for "does this evaluate / compile?" without
# touching the live system.
build:
	sudo nixos-rebuild --extra-experimental-features "nix-command flakes" build --flake $(FLAKE)#$(HOST)

# Build + activate but do NOT set as boot default. A reboot reverts.
# Safe way to try risky changes.
test:
	sudo nixos-rebuild --extra-experimental-features "nix-command flakes" test --flake $(FLAKE)#$(HOST)

# Pull latest versions of every flake input (updates flake.lock).
update:
	nix flake update

# Reclaim disk space from old generations (system + user).
clean:
	sudo nix-collect-garbage -d
	nix-collect-garbage -d

.PHONY: switch build test update clean
