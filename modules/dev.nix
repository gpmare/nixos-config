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
  ];

  # ============================================================
  #  direnv: auto-loads per-project devshells when you `cd` in.
  #  Pair with a .envrc file in each project (we'll cover later).
  # ============================================================
  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    # ----- Editors -----
    # VS Code is managed declaratively in home-manager/vscode.nix.
    # Neovim is managed declaratively in home-manager/neovim.nix.
    # Neither belongs here.

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

    # ----- Language runtimes (broad starter set) -----
    nodejs_24            # JavaScript / TypeScript projects
    python313            # Python projects + scripts

  ];

  # ============================================================
  #  MongoDB — run as a system service (data in /var/db/mongodb)
  # ============================================================
  services.mongodb.enable = true;
}
