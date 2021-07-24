args@{ config, lib, pkgs, hostname, ... }:


with builtins; with lib; let
  additionalArgs = rec {
    # Some configurations require unstable packages. The default variable, pkgs,
    # is linked to the stable channel and this one is included only for those
    # packages that require it
    unstable = import <nixpkgs-unstable> { config = config.nixpkgs.config; };
    # Several configs depend on Emacs. This ensure all of them use the same
    # package and are coupled together
    emacsPkg = unstable.emacs;
  };
  # A list of attribute sets containing the path of each module and a list of
  # machines it should apply to. This way I can ensure that some modules remain
  # common to all machines and others are specific to each one, while being all
  # included in the same configuration.
  allModules = [
    {
      # A general set of CLI tools and settings I use on an everyday basis
      path = ./home-modules/cli.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # My GUI desktop configuration: i3 + polybar + rofi (and more)
      path = ./home-modules/gui.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # My bare-bones Emacs experimental configuration
      path = ./home-modules/emacs.nix;
      machines = [ "korolev" ];
    }
    {
      # My Emacs (doom-emacs) personal configuration
      path = ./home-modules/doom-emacs.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # A basic keyboard layout and variant configuration
      path = ./home-modules/keyboard.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # My custom Firefox workflow and aesthetic settings
      path = ./home-modules/firefox.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # Neuron is a plaintext note-taking app and server
      path = ./home-modules/neuron.nix;
      machines = [ "vostok" "soyuz" ];
    }
    {
      # Different desktop applications that I need from time to time
      path = ./home-modules/desktop.nix;
      machines = [ "korolev" "vostok" ];
    }
    {
      # My personal mail configuration (mbsync + mu)
      path = ./home-modules/mail.nix;
      machines = [ "vostok" ];
    }
    {
      # My Spotify (official + spotifyd) setup
      path = ./home-modules/spotify.nix;
      machines = [ "korolev" "vostok" "soyuz" ];
    }
    {
      # Some of the music producing apps and packages
      path = ./home-modules/music.nix;
      machines = [ "vostok" ];
    }
    {
      # Some work-related specific settings
      path = ./home-modules/photography.nix;
      machines = [ "korolev" ];
    }
    {
      # Some work-related specific settings
      path = ./home-modules/work.nix;
      machines = [ "soyuz" ];
    }
  ];
  currentModules = filter (module: elem hostname module.machines) allModules;
  extendArguments = module: import module.path ( args // additionalArgs );
in {
  # Enable home-manager to manage the XDG standard
  xdg.enable = true;

  # Allow unfree packages for the user
  nixpkgs.config.allowUnfree = true;

  # Import the modules that are needed for this machine
  imports = map extendArguments currentModules;
}
