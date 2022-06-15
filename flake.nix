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

      ### Custom NixOS Builder ###
      buildCustomNixOSConfig = { system, pkgs, hostname, options, homeOptions }:
        let
          activeModules = lib.filterAttrs (name: set: builtins.isAttrs set) options;
          importModule = name: options: ( import ./nixos-modules/${name}.nix { inherit pkgs options; } );
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
              home-manager.extraSpecialArgs = { homeOptions = homeOptions.${hostname}; };
            }
          ]; 
        in lib.nixosSystem {
          inherit system pkgs;
          modules = hardwareImports ++ moduleImports ++ homeConfig;
        };

      homeOptions = {
        soyuz = {
          cli = { 
            info = {
              userName = "diego vicente";
              userEmail = "diego.vicente@decidesoluciones.es";
            };
          };
          gui = { };
          webcam = { device = "/dev/video2"; };
          keyboard = { };
          # emacs = { };
          vscode = { };
          work = { };
        };

        korolev = {
          cli = { 
            info = {
              userName = "Diego Vicente";
              userEmail = "mail@diego.codes";
            };
          };
          gui = { };
          webcam = { device = "/dev/video0"; };
          keyboard = { };
          emacs = { };
          vscode = { };
          photography = { };
        };
      };

      nixosOptions = {
        soyuz = {
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
            hostname = "soyuz";
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

        korolev = {
          configuration.stateVersion = "21.11";
          hardware = {
            fileSystems = { 
              # Add the media NVME mounted in /mnt/media
              "/mnt/media" = {
                device = "/dev/nvme1n1p2";
                fsType = "ntfs";
                # options = [ "data=journal" ];
              };
            };
          };
          boot = {
            maxGenerations = 2;  # Due to a small /boot partition
          };
          os = {
            updates = {
              # TODO: convert it to flakes properly
              enable = false;
              date = "Sun *-*-* 14:30:00";
            };
          };
          networking = {
            hostname = "korolev";
            wireless = "wlp6s0";
            ethernet = "enp7s0";
          };
          gpg = { };
          ssh = { };
          users = { };
          backup = {
            paths = [
              "/home"
              "/mnt/media"
            ];
            exclude = [
              "/home/*/usb"
              "/home/*/lib"
              "/mnt/media/games"
            ];
            borgbaseRepo = "mz2by24z@mz2by24z.repo.borgbase.com:repo";
            schedule = "14:15";
          };
          xserver = { };
          fonts = { };
          amd = { };
        };
      };

    in
    rec {
      nixosConfigurations = {
        soyuz = buildCustomNixOSConfig { 
          inherit system pkgs homeOptions;
          hostname = "soyuz";
          options = nixosOptions.soyuz;
        };

        korolev = buildCustomNixOSConfig { 
          inherit system pkgs homeOptions;
          hostname = "korolev";
          options = nixosOptions.korolev;
        };
      };

      homeConfigurations = {
        "dvicente@soyuz" = home-manager.lib.homeManagerConfiguration {
          # Specify the path to your home configuration here
          inherit system;
          username = "dvicente";
          configuration = import ./home.nix;
          homeDirectory = "/home/dvicente";
          extraSpecialArgs = homeOptions.soyuz;
        };

        "dvicente@korolev" = home-manager.lib.homeManagerConfiguration {
          # Specify the path to your home configuration here
          inherit system;
          username = "dvicente";
          configuration = import ./home.nix;
          homeDirectory = "/home/dvicente";
          extraSpecialArgs = homeOptions.korolev;
        };
      };
    };
}
