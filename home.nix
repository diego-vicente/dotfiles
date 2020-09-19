args@{ config, lib, pkgs, ... }:

# The home-manager configuration for my user. There are still some things to
# work out:
# TODO: generalize the declaration for work/personal machines
let
  additionalArgs = rec {
    # Some configurations require unstable packages. The default variable, pkgs,
    # is linked to the stable channel and this one is included only for those
    # packages that require it
    unstable = import <nixos-unstable> { config = config.nixpkgs.config; };
    # Several configs depend on Emacs. This ensure all of them use the same
    # package and are coupled together
    emacsPkg = unstable.emacs;
  };
  extendArguments = module: import module ( args // additionalArgs );
in {
  # Enable home-manager to manage the XDG standard
  xdg.enable = true;

  # Allow unfree packages for the user
  nixpkgs.config.allowUnfree = true;

  # Import all the different modules
  imports = let
    modules = [
      ./home-modules/gui.nix
      ./home-modules/cli.nix
      ./home-modules/emacs.nix
      ./home-modules/keyboard.nix
      ./home-modules/desktop.nix
      ./home-modules/mail.nix
      ./home-modules/firefox.nix
      ./home-modules/neuron.nix
      ./home-modules/spotify.nix
      # TODO: ./home-modules/music.nix
    ];
    # Invoke all the modules above with the extended set of arguments to
    # coordinate them if needed.
    in map extendArguments modules;
}
