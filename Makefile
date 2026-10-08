# Shortcut commands. Run `make <target>` from anywhere in the repo.
#
# HOST is which nixosConfiguration to build (matches flake.nix and
# hosts/<HOST>/). It defaults to this machine's hostname, so plain
# `make switch` does the right thing on every machine once its hostname
# is nucbox or dell. First switch after the 2026-10 merge (hostname still
# "gpmare"): pass it once, e.g. `make switch HOST=dell`.
# FLAKE is where the flake lives (`.` = current dir).

HOST  ?= $(shell hostname)
FLAKE ?= .

# Safety net: each host dir is tied to one physical machine (its disk
# UUIDs live in hardware-configuration.nix). Refuse to build/activate a
# host's config on the wrong hardware. Model = /sys/class/dmi/id/product_name.
MODEL_nucbox := NucBox K8 Plus
MODEL_dell   := Latitude 3540

check-host:
	@if [ ! -f hosts/$(HOST)/configuration.nix ]; then \
	  echo "No hosts/$(HOST)/ — known hosts: $$(ls -d hosts/*/ | xargs -n1 basename | tr '\n' ' ')"; \
	  echo "First switch on a machine still named 'gpmare'? Run: make switch HOST=nucbox  (mini PC)  or  make switch HOST=dell  (laptop)"; \
	  exit 1; \
	fi
	@want="$(MODEL_$(HOST))"; have="$$(cat /sys/class/dmi/id/product_name 2>/dev/null)"; \
	if [ -n "$$want" ] && [ "$$want" != "$$have" ]; then \
	  echo "Refusing: hosts/$(HOST) is for '$$want', but this machine is '$$have'."; \
	  exit 1; \
	fi

# Build + activate the new config now AND set it as the boot default.
switch: check-host
	sudo nixos-rebuild switch --flake $(FLAKE)#$(HOST)

# Build only — useful for "does this evaluate / compile?" without
# touching the live system.
build: check-host
	sudo nixos-rebuild build --flake $(FLAKE)#$(HOST)

# Build + activate but do NOT set as boot default. A reboot reverts.
# Safe way to try risky changes.
test: check-host
	sudo nixos-rebuild test --flake $(FLAKE)#$(HOST)

# Evaluate + list what would be built for EVERY host (no sudo, no activation).
# Run after any change to shared files.
check:
	@for h in $$(ls -d hosts/*/ | xargs -n1 basename); do \
	  echo "== $$h"; \
	  nix build --dry-run "$(FLAKE)#nixosConfigurations.$$h.config.system.build.toplevel" || exit 1; \
	done

# Pull latest versions of every flake input (updates flake.lock).
update:
	nix flake update

# Reclaim disk space from old generations (system + user).
clean:
	sudo nix-collect-garbage -d
	nix-collect-garbage -d

.PHONY: check-host switch build test check update clean
