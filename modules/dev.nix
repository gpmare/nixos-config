# Developer tooling: editors, git workflow, modern CLI utilities,
# and language runtimes for general project work.

{ config, lib, pkgs, ... }:

{
  # ============================================================
  #  direnv: auto-loads per-project devshells when you `cd` in.
  #  Pair with a .envrc file in each project (we'll cover later).
  # ============================================================
  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    # ----- Editors -----
    vscode               # Familiar GUI editor (Windows VSCode transplant)
    neovim               # Modal terminal editor; try when curious

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

    # ----- Language runtimes (broad starter set) -----
    nodejs_22            # JavaScript / TypeScript projects
    python313            # Python projects + scripts
  ];
}
