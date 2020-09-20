# Bootstrap for the vostok host - it simply adds the correct hostname to the
# argument set that is passed to the configuration.nix file.
# Expected use:
#   $ sudo ln -s ./bootstrap/vostok.nix /etc/nixos/configuration.nix
args@{ config, lib, pkgs, ... }:

let
  additionalArgs = {
    hostname = "vostok";
  };
  extendedArgs = args // additionalArgs;
in
  import ../configuration.nix extendedArgs
