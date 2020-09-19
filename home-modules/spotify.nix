{ config, lib, pkgs, ... }:

{
  # Install both the regular, non-free app and the TUI client.
  home.packages = with pkgs; [
    spotify
    spotify-tui
  ];

  # Enable the Spotifyd service for the TUI client to connect to.
  services.spotifyd = {
    enable = true;
    settings = {
      global = {
        username = "diegovicente";
        # TODO: check if the pkg explicit call and output redirection are needed
        password_cmd = "${pkgs.gnupg}/bin/gpg --decrypt ~/etc/dotfiles/passwords/spotify.asc 2> /dev/null";
        bitrate = "320";
        # TODO: generalize to use the machine hostname
        device_name = "Spotifyd@vostok";
      };
    };
  };
}
