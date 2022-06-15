{ pkgs, inputs, lib, ... }:

{
  buildCustomNixOSConfig = { system, pkgs, hostname, options }:
    let
      activeModules = lib.filterAttrs (name: set: builtins.isAttrs set) options.${hostname}.nixos;
      importModule = name: _: ../nixos-modules/${name}.nix;
      # Move hardware imports to allow for development only environments
      hardwareImports = [ ../hardware-configuration/${hostname}.nix ];
      # overlays = [ { nixpkgs.overlays = import ./nixos-modules/overlays.nix; } ];
      moduleImports = lib.attrsets.mapAttrsToList importModule activeModules;
      homeConfig = [ 
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dvicente = import ../home.nix;
          home-manager.extraSpecialArgs = { homeOptions = options.${hostname}.homeManager; };
        }
      ]; 
    in lib.nixosSystem {
      inherit system pkgs;
      modules = hardwareImports ++ moduleImports ++ homeConfig;
      specialArgs = { nixosOptions = options.${hostname}.nixos; };
    };

  buildCustomHomeConfig = { system, hostname, options }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit system;
      username = "dvicente";
      configuration = import ../home.nix;
      homeDirectory = "/home/dvicente";
      extraSpecialArgs = options.${hostname}.homeManager;
    };
}
