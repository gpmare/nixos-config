# VS Code, configured declaratively.
#
# Because home-manager manages VS Code here, the editor + its extensions
# + its settings ALL come from this file. Rebuild and you get exactly
# this, on any machine. (This is why VS Code was removed from the system
# packages in modules/dev.nix — one source of truth.)
#
# The point of this setup: editing your .nix files gets autocomplete of
# valid NixOS/home-manager options and red error-squiggles BEFORE you
# rebuild — via the `nixd` Nix language server, wired up below.

{ config, pkgs, ... }:

{
  programs.vscode = {
    enable = true;

    profiles.default = {
      # Extensions come from nixpkgs (pinned by your flake) — no clicking
      # "Install" in the GUI, and they can't silently auto-update on you.
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide      # Nix language support: highlighting + LSP glue
      ];

      # These are the entries that normally live in VS Code's settings.json
      # (the cog → "Settings (JSON)"). Declared here instead.
      userSettings = {
        # Point the Nix extension at the nixd language server. Using the
        # absolute store path means it works regardless of PATH.
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nixd}/bin/nixd";

        # Small quality-of-life defaults.
        "files.trimTrailingWhitespace" = true;
        "editor.tabSize" = 2;            # Nix convention is 2-space indents
      };
    };
  };

  # The language server binary itself (the extension just talks to it).
  # Also handy on the terminal.
  home.packages = [ pkgs.nixd ];
}
