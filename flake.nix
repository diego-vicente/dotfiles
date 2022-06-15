{
  description = "Diego Vicente's personal configuration";

  inputs = {
    # Target channel for the configuration
    nixpkgs.url = "nixpkgs/nixos-22.05";
    unstable.url = "nixpkgs/nixos-unstable";

    # home-manager version for user management
    home-manager = {
      url = "github:nix-community/home-manager/release-22.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, unstable, home-manager, ... }:
    let
      system = "x86_64-linux";  # TODO: be more general for ARM?

      commonConfig = { allowUnfree = true; };

      # Import unstable packages with the common config
      unstablePkgs = import unstable {
        inherit system; 
        config = commonConfig;
      };

      # Import the stable packages with the common config and include the
      # unstable as an attribute
      pkgs = import nixpkgs {
        inherit system;
        overlays = import ./nixos-modules/overlays.nix;
        config = commonConfig // {
          packageOverrides = pkgs: {
            unstable = unstablePkgs;
          };
        };
      };

      lib = nixpkgs.lib;

      options = import ./options.nix;

      ### Custom NixOS Builder ###
      buildCustomNixOSConfig = { system, pkgs, hostname, options }:
        let
          activeModules = lib.filterAttrs (name: set: builtins.isAttrs set) options.${hostname}.nixos;
          importModule = name: _: ./nixos-modules/${name}.nix;
          # Move hardware imports to allow for development only environments
          hardwareImports = [ ./hardware-configuration/${hostname}.nix ];
          # overlays = [ { nixpkgs.overlays = import ./nixos-modules/overlays.nix; } ];
          moduleImports = lib.attrsets.mapAttrsToList importModule activeModules;
          homeConfig = [ 
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.dvicente = import ./home.nix;
              home-manager.extraSpecialArgs = { homeOptions = options.${hostname}.homeManager; };
            }
          ]; 
        in lib.nixosSystem {
          inherit system pkgs;
          modules = hardwareImports ++ moduleImports ++ homeConfig;
          specialArgs = { nixosOptions = options.${hostname}.nixos; };
        };

      buildCustomHomeConfig = { system, hostname, options }:
        home-manager.lib.homeManagerConfiguration {
          inherit system;
          username = "dvicente";
          configuration = import ./home.nix;
          homeDirectory = "/home/dvicente";
          extraSpecialArgs = options.${hostname}.homeManager;
        };

    in
    rec {
      nixosConfigurations = {
        soyuz = buildCustomNixOSConfig { 
          inherit system pkgs options;
          hostname = "soyuz";
        };

        korolev = buildCustomNixOSConfig { 
          inherit system pkgs options;
          hostname = "korolev";
        };
      };

      homeConfigurations = {
        "dvicente@soyuz" = buildCustomHomeConfig {
          inherit system options;
          hostname = "soyuz";
        };

        "dvicente@korolev" = buildCustomHomeConfig {
          inherit system options;
          hostname = "korolev";
        };
      };
    };
}
