{ pkgs, lib, inputs ? {}, ... }:

rec {
  # Map a set of options to a list of modules to be imported.
  #
  # The logic behind the options.nix file is quite simple: if there is a set in
  # the options set, the module named after it should be imported to perform all
  # necessary configurations. It does not matter if the set is emtpy (most sets
  # actuall are if no further options are required).
  optionsToImports = options: path:
    let
      # The module is considered active if there is a set with its name
      activeModules = lib.filterAttrs (name: set: builtins.isAttrs set) options;
      # The module is relative to the given path
      inferPath = name: _: path + "/${name}.nix";
    in lib.attrsets.mapAttrsToList inferPath activeModules;

  # Build a custom configuration for outputs.nixosConfigurations
  #
  # This function takes care of setting the three main parts of the host
  # definition: the hardware file, the NixOS configuration and the home-manager
  # options. Most of them are actually instructed using the options.nix file.
  buildCustomNixOSConfig = { system, pkgs, hostname, options, hardware ? true}:
    let
      # Import the given hardware file unless instructed otherwise
      hardwareImports = if hardware then [ ../hardware-configuration/${hostname}.nix ] else [ ];
      # The NixOS configuration is inferred from the options.nix file
      nixosOptions = options.${hostname}.nixos;
      configurationModules = optionsToImports nixosOptions ../nixos-modules;
      # A home-manager configuration is linked to each host to create the default user
      homeOptions = options.${hostname}.homeManager;
      homeConfig = [
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dvicente = ../home.nix;
          home-manager.extraSpecialArgs = { inherit homeOptions; };
        }
      ];
    in lib.nixosSystem {
      inherit system pkgs;
      modules = hardwareImports ++ configurationModules ++ homeConfig;
      specialArgs = { inherit nixosOptions; };
    };

  # Build a custom configuration for outputs.homeConfigurations
  #
  # Although not oficially supported, this function allows the home-manager
  # configurations to be defined as homeConfigurations in case they have to be
  # used in a non-NixOS machine.
  buildCustomHomeConfig = { system, hostname, options, username ? "dvicente" }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit system username;
      configuration = import ../home.nix;
      homeDirectory = "/home/${username}";
      extraSpecialArgs = options.${hostname}.homeManager;
    };
}