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
    python313            # Python projects + scripts

  ];

  # ============================================================
  #  MongoDB — run as a system service (data in /var/db/mongodb)
  # ============================================================
  services.mongodb.enable = true;
}
