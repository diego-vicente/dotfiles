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

  outputs = { self, nixpkgs, unstable, home-manager, ... }@inputs:
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

      lib = nixpkgs.lib.extend
        (self: super: { dvm = import ./lib { inherit pkgs inputs; lib = self; }; });

      options = import ./options.nix;

    in
    rec {
      nixosConfigurations = {
        soyuz = lib.dvm.buildCustomNixOSConfig { 
          inherit system pkgs options;
          hostname = "soyuz";
        };

        korolev = lib.dvm.buildCustomNixOSConfig { 
          inherit system pkgs options;
          hostname = "korolev";
        };
      };

      homeConfigurations = {
        "dvicente@soyuz" = lib.dvm.buildCustomHomeConfig {
          inherit system options;
          hostname = "soyuz";
        };

        "dvicente@korolev" = lib.dvm.buildCustomHomeConfig {
          inherit system options;
          hostname = "korolev";
        };
      };
    };
}
