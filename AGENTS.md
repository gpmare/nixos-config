# Agent guide — nixos-config

Project-specific rules for AI agents editing this flake. Global style/workflow
lives in `~/.claude/CLAUDE.md` (sourced from `home-manager/agent-instructions.md`).
This file is about **where things live** and **how to change them so rebuilds
succeed on the first try**.

**Host / user / flake attr:** `gpmare` · **System:** `x86_64-linux` · **Channel:** `nixos-unstable`

---

## Config index — where to put what

| Want to… | Edit |
| --- | --- |
| Add a GUI app / system-wide binary on `$PATH` | `modules/packages.nix` |
| Add CLI / git / language runtimes / nix-ld libs | `modules/dev.nix` |
| Change boot, network, locale, SSH, GC, fonts, unfree | `modules/system.nix` |
| Change Plasma / SDDM / Wayland / RDP / DDC brightness kernel bits | `modules/desktop.nix` |
| Change PipeWire / musnix / Scarlett audio | `modules/audio.nix` |
| Per-host hostname, LUKS UUID, user groups | `hosts/gpmare/configuration.nix` |
| Hardware (kernel modules, filesystems) — **installer-generated** | `hosts/gpmare/hardware-configuration.nix` |
| User identity, bash aliases, starship, git, mise, HM imports | `home-manager/gpmare.nix` |
| Kitty theme / Plasma default terminal | `home-manager/kitty.nix` |
| VS Code / Cursor / Neovim | `home-manager/vscode.nix`, `cursor.nix`, `neovim.nix` |
| Brave web-app desktop entries (Calendar, WhatsApp, YT Music) | `home-manager/web-apps.nix` |
| External-monitor brightness fix (user-level) | `home-manager/brightness.nix` |
| Package **not** in nixpkgs (AppImage, local drv) | `pkgs/<name>.nix` + `callPackage` from a module |
| Flake inputs / host wiring / home-manager glue | `flake.nix` |
| Pin of all inputs | `flake.lock` (via `make update`, not by hand) |
| Global agent response style (synced to `~/.claude/CLAUDE.md`) | `home-manager/agent-instructions.md` |
| Human-facing overview | `README.md` |
| Rebuild shortcuts | `Makefile` (`switch`, `build`, `test`, `update`, `clean`) |

### Layout (evaluation graph)

```
flake.nix
  └─ nixosConfigurations.gpmare
       ├─ hosts/gpmare/configuration.nix
       │    imports → modules/{system,desktop,audio,dev,packages}.nix
       │              + hardware-configuration.nix
       ├─ musnix, nix-index-database, home-manager (external modules)
       └─ home-manager.users.gpmare ← home-manager/gpmare.nix
            imports → neovim, vscode, cursor, brightness, kitty, web-apps
```

`specialArgs` / `extraSpecialArgs` already pass `inputs`, `username`, `hostname`.
Modules that need them declare them in the function header; do not re-hardcode.

### Placement rules of thumb

- **System package** (any user, on PATH after rebuild) → `environment.systemPackages` in the matching `modules/*.nix`.
- **User-only config** (dotfiles, `programs.*`, desktop entries, HM packages) → `home-manager/`.
- **Editors:** package + HM module stay together in the editor’s HM file (see comments in `modules/dev.nix`); do not also list them in `packages.nix`.
- **New HM file:** create it, then add to `imports` in `home-manager/gpmare.nix`.
- **New system module:** create under `modules/`, then add to `imports` in `hosts/gpmare/configuration.nix`.
- **Not in nixpkgs:** write `pkgs/<name>.nix`, then e.g. `(callPackage ../pkgs/<name>.nix { })` in the module that should install it (see `pomotroid`).

---

## Best practice: edit so the rebuild succeeds first time

Flakes in a Git repo only evaluate **Git-tracked** files. Untracked paths are
invisible even if they exist on disk — classic failure mode for new modules.

Sources: [Nix flake Git behaviour](https://jvns.ca/blog/2023/11/11/notes-on-nix-flakes/),
[NixOS & Flakes Book — tips](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/other-useful-tips),
[agent deploy lessons on NixOS](https://dev.to/0coceo/10-things-i-learned-running-20-autonomous-ai-agent-services-on-nixos-145g).

### Mandatory workflow (do every change)

1. **Find the right file** using the index above. Prefer a one-line package
   add over a new module unless structure needs it.
2. **Confirm the attr exists** before adding packages:
   ```bash
   # From this repo (uses flake’s nixpkgs pin)
   nix eval '.#nixosConfigurations.gpmare.pkgs.<pname>.name'
   # Or search
   nix search nixpkgs '^<name>$'
   ```
   If it does not exist, either pick the correct attr name or package it under
   `pkgs/` — do not invent names.
3. **Edit** with a minimal diff. Match existing comment style. Do not bump
   `system.stateVersion` / `home.stateVersion` unless the user asks.
4. **Wire imports** if you added a new `.nix` file (HM `imports` or host
   `imports`). A file that is never imported never runs.
5. **`git add` every new path the flake must see** (stage is enough; commit only
   if the user asks):
   ```bash
   git add path/to/new-file.nix
   ```
   Dirty edits to *already tracked* files are fine. **Untracked files are not.**
6. **Evaluate before handing off** (user rebuilds themselves unless they ask
   you to). Prefer dry evaluation over full `switch`:
   ```bash
   # Fast: does the config evaluate?
   nix build --dry-run '.#nixosConfigurations.gpmare.config.system.build.toplevel'

   # Or full compile without activating (needs sudo via Makefile):
   make build
   ```
   On failure: re-run with `--show-trace` (or `nixos-rebuild … --show-trace -L`).
7. **Tell the user** to apply with `make switch` (or their `rebuild` alias).
   Do not run `switch`/`test` unless asked — activation is privileged and
   changes the live system.

### Extra checks that prevent second/third attempts

| Situation | Do this first |
| --- | --- |
| New file under `modules/`, `home-manager/`, `pkgs/`, `hosts/` | `git add` it |
| Package name unknown | `nix eval` / `nix search` against **this flake’s** pkgs |
| Unfree app (VS Code, Brave, Reaper, …) | Already allowed (`nixpkgs.config.allowUnfree` in `system.nix`) |
| Local AppImage / binary package | Prefetch hash: `nix-prefetch-url --type sha256 <url>` then `nix hash convert --from nix32 --to sri --hash-algo sha256 <hash>`; put SRI in `hash = "sha256-…"` |
| Hash wrong | Build once, paste the `got:` SRI Nix prints — do not guess |
| `callPackage ./foo.nix` path | Relative to the **module file** that calls it, not the repo root (`packages.nix` → `../pkgs/…`) |
| Home Manager would clobber a file | Backup command is already set (timestamped `.hm-bak.*`); still avoid managing files the user edits by hand |
| Changing a running systemd unit’s script | Rebuild alone may not restart it; note that the user may need `systemctl restart …` |

### Anti-patterns (this repo)

- Do **not** leave new flake inputs/modules untracked and hope `make switch` works.
- Do **not** use `path:` flake refs or parent-dir hacks to skip `git add` — stage the file.
- Do **not** put one-off packages in `flake.nix` inline when `modules/` or `pkgs/` is the established place.
- Do **not** change `hardware-configuration.nix` unless hardware actually changed.
- Do **not** enable Blueman (`system.nix` documents why — Plasma owns Bluetooth UI).
- Do **not** duplicate global agent rules into `~/.grok/rules/` or a home `AGENTS.md` (see comment in `gpmare.nix`).
- Do **not** commit, push, or open PRs unless the user asks.
- Do **not** run `make update` (flake lock bump) unless asked — large, unrelated churn.

---

## Common edit recipes

### Add a package that is in nixpkgs

```nix
# modules/packages.nix (desktop) or modules/dev.nix (CLI)
environment.systemPackages = with pkgs; [
  # …
  some-package
];
```

### Add a package not in nixpkgs

1. Create `pkgs/foo.nix` (prefer `appimageTools.wrapType2` for AppImages; see `pkgs/pomotroid.nix`).
2. In the installing module: `(callPackage ../pkgs/foo.nix { })`.
3. `git add pkgs/foo.nix` and the module edit.
4. Dry-build / `make build`.

### Add a Home Manager feature module

1. Create `home-manager/foo.nix` with `{ config, pkgs, lib, … }: { … }`.
2. Append `./foo.nix` to `imports` in `home-manager/gpmare.nix`.
3. `git add` both paths.

### Web app with no good native client

Add an `xdg.desktopEntries.*` entry in `home-manager/web-apps.nix` (Brave `--app=` pattern already used).

---

## Rebuild commands (user-facing)

| Command | Effect |
| --- | --- |
| `make switch` | Build + activate + set boot default |
| `make build` | Build only (good agent verification if allowed) |
| `make test` | Activate without changing boot default |
| `make update` | `nix flake update` (inputs only) |
| `make clean` | GC old generations |

Flake ref: `~/nixos-config#gpmare` (also the `rebuild` bash alias).

Rollback if a bad generation is activated: `sudo nixos-rebuild switch --rollback`.

---

## Quick pre-handoff checklist

- [ ] Right file(s) for the task (index above)
- [ ] Package attr verified or local `pkgs/` drv written
- [ ] New modules imported where required
- [ ] **All new paths `git add`ed**
- [ ] Config evaluates (`nix build --dry-run …` or `make build`)
- [ ] User told to `make switch` (unless they asked you to rebuild)
- [ ] No unsolicited lockfile bumps, commits, or refactors
