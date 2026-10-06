# Developer tooling: editors, git workflow, modern CLI utilities,
# and language runtimes for general project work.

{ config, lib, pkgs, ... }:

{
  # Allows dynamically-linked binaries built for generic Linux to run on NixOS.
  # Required for VSCode extensions that ship pre-compiled binaries (e.g. Claude Code).
  programs.nix-ld.enable = true;

  # Shared libraries those foreign binaries link against at runtime. Without
  # libstdc++/libgcc here, mise cannot exec its pre-built Node download and
  # silently falls back to compiling Node from source — which fails on NixOS.
  # Also lets mongodb-memory-server run its own downloaded mongod if needed.
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib   # libstdc++.so.6, libgcc_s.so.1
    zlib
    openssl
    curl
  ]
  # Playwright downloads its own Chromium and Firefox builds (pinned per
  # project, e.g. @playwright/test 1.60) rather than using system browsers, and
  # those binaries are linked against a normal FHS distro. Without the closure
  # below they die at launch with
  #   error while loading shared libraries: libglib-2.0.so.0
  # before a single test runs. Listing them here rather than pointing
  # PLAYWRIGHT_BROWSERS_PATH at nixpkgs' `playwright-driver` is deliberate:
  # that package tracks its own version (1.61.1 today) and Playwright refuses
  # a browser revision it did not pin, so it breaks every time either side
  # bumps. nix-ld keeps working whatever version a project pins.
  ++ (with pkgs; [
    # Core GLib/GTK stack
    glib
    gtk3
    gdk-pixbuf
    pango
    cairo
    atk
    at-spi2-atk
    at-spi2-core
    dbus
    dbus-glib        # Firefox
    expat

    # Crypto + fonts
    nss
    nspr
    fontconfig
    freetype

    # Graphics / input
    libgbm           # Chromium's GPU buffer manager (split out of mesa)
    mesa
    libxkbcommon
    libdrm
    alsa-lib
    libnotify        # Firefox
    libxml2          # Firefox
    libxslt          # Firefox
    cups
    systemd          # libudev.so.1

    # X11 (top-level names; the `xorg.*` set is deprecated)
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxt            # Firefox
    libxtst
    libxcb
    libxshmfence
  ]);

  # ============================================================
  #  direnv: auto-loads per-project devshells when you `cd` in.
  #  Pair with a .envrc file in each project (we'll cover later).
  # ============================================================
  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    # ----- Editors -----
    # VS Code  → home-manager/vscode.nix
    # Cursor   → home-manager/cursor.nix  (FHS build; Nix owns updates)
    # Neovim   → home-manager/neovim.nix
    # None of those belong here.

    # ----- Git / GitHub -----
    git
    gh                   # GitHub CLI (auth, repo, PR, issues from terminal)
    lazygit              # TUI for git — visual stage/commit/diff/push

    # ----- Modern CLI replacements -----
    ripgrep              # `rg` — fast grep that respects .gitignore
    fd                   # `fd` — fast `find` with friendlier syntax
    bat                  # `bat` — `cat` with syntax highlighting + paging
    eza                  # `eza` — `ls` with colors, icons, git status
    fzf                  # fuzzy finder; great with Ctrl+R shell history

    # ----- Build tools -----
    gnumake              # `make` — runs targets defined in Makefile
    just                 # `just` — command runner; task runner used by many repos
    uv                   # Fast Python package manager; used by Serena MCP

    # ----- Browser automation -----
    # A real Chromium on PATH, needed by two things that will not use the
    # Brave/Edge builds above:
    #   * chrome-devtools-mcp, which wants an explicit `-e /path/to/chromium`
    #     (see .mcp.json.example in the template repo)
    #   * Playwright's documented NixOS escape hatch, if the nix-ld route above
    #     ever falls short: PLAYWRIGHT_CHROMIUM_BIN="$(which chromium)" just test-e2e
    chromium

    # ----- Language runtimes (broad starter set) -----
    nodejs_24            # JavaScript / TypeScript projects
    # System-wide, not mise: agents spawn non-interactive shells that never
    # load mise shims, and every gate recipe is `bun run` / `bun test` / `bunx`.
    # Elysia backend tests also need Bun's globals (`Bun`, `bun:test`).
    bun
    # Standalone binary. Node's corepack cannot write pnpm shims into the
    # read-only nix store prefix, so `corepack enable pnpm` is a no-op here.
    pnpm
    # lowPrio: `python3` on PATH is the withPackages env in packages.nix.
    (lib.lowPrio python313)  # Python projects + scripts (`python3.13`)

  ];

  # ============================================================
  #  MongoDB — run as a system service (data in /var/db/mongodb)
  # ============================================================
  services.mongodb.enable = true;

  # Raise the open-file limit for mongod. The nixpkgs module sets no
  # LimitNOFILE, so systemd's default applies — soft 1024, hard 524288 — and
  # mongod does not raise its own soft limit at startup. The template repo's
  # backend suite gives each of its ~26 suites its own database, and the
  # resulting WiredTiger file handles blow past 1024 part-way through a run:
  #   Location13538 "couldn't open [/proc/<pid>/stat] Too many open files"
  # immediately followed by a fatal assertion in wiredtiger_util.cpp, i.e.
  # mongod dies mid-suite and every later test fails as a connection error.
  # A single value sets soft = hard, which is what actually fixes it; 64000 is
  # MongoDB's own documented recommendation.
  # Verify after a rebuild with:
  #   grep 'Max open files' /proc/$(pgrep -x mongod)/limits
  systemd.services.mongodb.serviceConfig.LimitNOFILE = 64000;

  # The template suite (and leftover `mongod --dbpath /tmp/dev-db-integrate`)
  # also binds :27017. nixpkgs' forking unit then fails with exit 48
  # ("Address already in use") and `nixos-rebuild switch` returns 4 even
  # though the new generation activated. ExecCondition 1–254 = skip, not fail.
  systemd.services.mongodb.serviceConfig.ExecCondition =
    pkgs.writeShellScript "mongodb-port-free" ''
      if ${pkgs.iproute2}/bin/ss -H -ltn 'sport = :27017' \
           | ${pkgs.gnugrep}/bin/grep -q .; then
        echo "mongodb: :27017 already in use; skipping system mongod" >&2
        exit 1
      fi
    '';
}
