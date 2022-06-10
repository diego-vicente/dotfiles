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

      unstable = import unstable {
        inherit system; 
        config = commonConfig;
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = import ./nixos-modules/overlays.nix;
        config = commonConfig // {
          packageOverrides = pkgs: {
            inherit unstable;
          };
        };
      };

      lib = nixpkgs.lib;

      ### Custom NixOS Builder ###
      buildCustomNixOSConfig = { system, pkgs, hostname, options }:
        let
          activeModules = lib.filterAttrs (name: set: builtins.isAttrs set) options;
          importModule = name: options: import ./nixos-modules/${name}.nix { inherit pkgs options;
          };
          hardwareImports = [ ./hardware-configuration/${hostname}.nix ];
          moduleImports = lib.attrsets.mapAttrsToList importModule activeModules;
        in
        lib.nixosSystem {
          inherit system pkgs;
          modules = hardwareImports ++ moduleImports;
        };

      ### Custom home-manager Builder ###
      buildCustomHomeManagerConfig = { system, pkgs, hostname, options }:
        let
          activeModules = lib.filterAttrs (name: set: builtins.isAttrs set) options;
          importModule = name: options: import ./home-modules/${name}.nix { inherit pkgs options;
          };
          moduleImports = lib.attrsets.mapAttrsToList importModule activeModules;
        in
        home-manager.lib.homeManagerConfiguration {
          inherit system pkgs;
          username = "dvicente";
          homeDirectory = "home/dvicente";
          configuration = {
            # Enable home-manager to manage the XDG standard
            xdg.enable = true;

            # Allow unfree packages for the user
            nixpkgs.overlays = import ./home-modules/overlays.nix;

            # Include module imports
            imports = moduleImports;
          };
        };

    in

    {
      nixosConfigurations = {
        soyuz = buildCustomNixOSConfig rec {
          inherit system pkgs;
          hostname = "soyuz";
          options = {
            configuration.stateVersion = "21.11";
            hardware = {
              fileSystems = { };
            };
            boot = {
              maxGenerations = 10;
            };
            os = {
              updates = {
                # TODO: convert it to flakes properly
                enable = false;
                date = "Fri *-*-* 16:00:00";
              };
            };
            networking = {
              inherit hostname;
              enableImport = true;
              wireless = "wlp59s0";
            };
            gpg = { };
            ssh = { };
            users = { };
            backup = {
              paths = [ "/home" ];
              exclude = [
                "/home/*/usb"
                "/home/*/lib"
              ];
              borgbaseRepo = "k6vw052b@k6vw052b.repo.borgbase.com:repo";
              schedule = "14:00";
            };
            xserver = { };
            fonts = { };
            nvidia = {
              pci = {
                intelBusId = "PCI:0:2:0";
                nvidiaBusId = "PCI:1:0:0";
              };
            };
            docker = { };
          };
        };
      };

      homeConfigurations = {
        dvicente = buildCustomHomeManagerConfig {
          inherit system pkgs;
          hostname = "soyuz";
          options = {
            cli = { 
              info = {
                userName = "Diego Vicente";
                userEmail = "diego.vicente@decidesoluciones.es";
              };
            };
            gui = { };
            webcam = { device = "/dev/video2"; };
            keyboard = { };
            emacs = { };
            vscode = { };
            work = { };
          };
        };
      };
    };
}
