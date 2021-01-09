args@{ config, lib, pkgs, hostname, hostSpecific, ... }:

with builtins; with lib; let
  allModules = [
    {
      # The general hardware configuration
      path = ./nixos-modules/hardware.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # Power consumption and monitoring utilities
      path = ./nixos-modules/power.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # Boot configuration and other kernel flags
      path = ./nixos-modules/boot.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # Networking configuration
      path = ./nixos-modules/networking.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # GPG service setup
      path = ./nixos-modules/gpg.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # SSH service configuration
      path = ./nixos-modules/ssh.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # User configuration for the system
      path = ./nixos-modules/users.nix;
      machines = [ "vostok" "soyuz" ];
    }
    # FIXME: "called without required argument 'utils'"
    # {
    #   # home-manager's official channel
    #   path = <home-manager/nixos>;
    #   machines = [ "vostok" ];
    # }
    {
      # X server configuration and related utilities
      path = ./nixos-modules/xserver.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # The font configuration for the system
      path = ./nixos-modules/fonts.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # Configuration for the Optimus nvidia setup
      path = ./nixos-modules/nvidia.nix;
      machines = [ "vostok" "soyuz" ];
    }
  ];
  currentModules = filter (module: elem hostname module.machines) allModules;
  extendArguments = module: import module.path args;
in
{
  # Allow non-free packages and include the unstable channel
  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      unstable = import <nixpkgs-unstable> {
        config = config.nixpkgs.config;
      };
    };
  };

  # Import the modules that are needed for this machine
  imports =
    [ <home-manager/nixos> ]
    ++ map extendArguments currentModules;

  # home-manager configuration
  home-manager.users.dvicente = import ./home.nix args;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
