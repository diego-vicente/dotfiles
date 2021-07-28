args@{ config, lib, pkgs, hostname, hostSpecific, ... }:

with builtins; with lib; let
  allModules = [
    {
      # The general hardware configuration
      path = ./nixos-modules/hardware.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # Power consumption and monitoring utilities
      path = ./nixos-modules/power.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # Boot configuration and other kernel flags
      path = ./nixos-modules/boot.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # Settings and housekeeping tasks related to the OS
      path = ./nixos-modules/os.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # Networking configuration
      path = ./nixos-modules/networking.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # GPG service setup
      path = ./nixos-modules/gpg.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # SSH service configuration
      path = ./nixos-modules/ssh.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # User configuration for the system
      path = ./nixos-modules/users.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # Backup mechanisms for the given hosts
      path = ./nixos-modules/backup.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # X server configuration and related utilities
      path = ./nixos-modules/xserver.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # The font configuration for the system
      path = ./nixos-modules/fonts.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # Configuration for the Optimus nvidia setup
      path = ./nixos-modules/nvidia.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # Configuration for AMD GPUs
      path = ./nixos-modules/amd.nix;
      machines = [ "korolev" ];
    }
    {
      # Enable virtualization via Docker
      path = ./nixos-modules/docker.nix;
      machines = [ "soyuz" ];
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

  # Configure flakes system-wide (it is unstable, but it is the future)
  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # home-manager configuration
  home-manager.users.dvicente = import ./home.nix args;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
