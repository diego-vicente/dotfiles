{ config, lib, pkgs, hostname, ... }:

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
        password_cmd = "${pkgs.gnupg}/bin/gpg --decrypt ${../passwords/spotify.asc}";
        bitrate = "320";
        device_name = "Spotifyd@${hostname}";
      };
    };
  };
}
