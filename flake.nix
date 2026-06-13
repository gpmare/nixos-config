{
  description = "Gerhard's NixOS system configuration";

  # ============================================================
  #  Inputs: external sources this flake depends on.
  #
  #  `follows` makes each input share our nixpkgs instead of
  #  pulling its own copy — saves disk + avoids version drift.
  # ============================================================
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    musnix = {
      url = "github:musnix/musnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-index-database powers `command-not-found`: when you type a
    # missing command, it tells you which package provides it.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland: tiling Wayland compositor. Pin to the upstream flake
    # for newer features than nixpkgs ships.
    hyprland.url = "github:hyprwm/Hyprland";
  };

  # ============================================================
  #  Outputs: what this flake provides.
  #  `outputs` is a FUNCTION from inputs -> attribute set.
  # ============================================================
  outputs = { self, nixpkgs, home-manager, musnix, nix-index-database, ... }@inputs:
    let
      system   = "x86_64-linux";
      hostname = "gpmare";
      username = "gpmare";
    in {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;

        # specialArgs is how we hand `inputs`, `username`, etc. down
        # to every module — so they don't have to redeclare them.
        specialArgs = { inherit inputs username hostname; };

        modules = [
          # The host's own entry-point — pulls in our modules/.
          ./hosts/${hostname}/configuration.nix

          # External NixOS modules.
          musnix.nixosModules.musnix
          nix-index-database.nixosModules.nix-index
          home-manager.nixosModules.home-manager

          # Inline module: configure home-manager itself.
          {
            home-manager.useGlobalPkgs   = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs username; };
            home-manager.users.${username} =
              import ./home-manager/${username}.nix;
          }
        ];
      };
    };
}
