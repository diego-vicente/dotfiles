{ config, lib, pkgs, ... }:

{
  # Install other desktop apps without in depth-configuration.
  home.packages = with pkgs; [
    chromium
    calibre
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
  ];
}
