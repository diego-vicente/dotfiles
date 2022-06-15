
{ lib, pkgs, homeOptions, ... }:

let
  activeModules = lib.filterAttrs (name: set: builtins.isAttrs set) homeOptions;
  importModule = name: _: ./home-modules/${name}.nix;
  moduleImports = lib.attrsets.mapAttrsToList importModule activeModules;
in
{
  # Let home-manager install itself
  programs.home-manager.enable = true;

  # Enable home-manager to manage the XDG standard
  xdg.enable = true;

  # Allow unfree packages for the user
  nixpkgs.overlays = import ./home-modules/overlays.nix;

  # Import the modules that are needed for this machine
  imports = moduleImports;
}
