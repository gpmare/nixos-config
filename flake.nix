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

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  # ============================================================
  #  Outputs: what this flake provides.
  #  `outputs` is a FUNCTION from inputs -> attribute set.
  # ============================================================
  outputs = { self, nixpkgs, home-manager, musnix, nix-index-database, plasma-manager, ... }@inputs:
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
          ({ pkgs, ... }: {
            home-manager.useGlobalPkgs   = true;
            home-manager.useUserPackages = true;
            # If HM would overwrite a file it doesn't own, move it aside
            # with a unique timestamped suffix. A fixed ".hm-bak" collides
            # on the second rebuild and aborts activation.
            home-manager.backupCommand =
              "${pkgs.coreutils}/bin/mv \"$1\" \"$1.hm-bak.$(${pkgs.coreutils}/bin/date +%Y%m%d%H%M%S)\"";
            home-manager.extraSpecialArgs = { inherit inputs username; };
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
            home-manager.users.${username} =
              import ./home-manager/${username}.nix;
          })
        ];
      };
    };
}
