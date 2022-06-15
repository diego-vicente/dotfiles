
{ lib, pkgs, homeOptions, ... }:

let
  # TODO: how to propagate lib.dvm here as well?
  dvmLib = import ./lib { inherit pkgs lib; };
in {
  # Let home-manager install itself
  programs.home-manager.enable = true;

  # Enable home-manager to manage the XDG standard
  xdg.enable = true;

  # Allow unfree packages for the user
  nixpkgs.overlays = import ./home-modules/overlays.nix;

  # Import the modules that are needed for this machine
  imports = dvmLib.optionsToImports homeOptions ./home-modules;
}
