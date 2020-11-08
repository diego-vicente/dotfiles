{ config, lib, pkgs, ... }:

{
  # Install other desktop apps without in depth-configuration.
  home.packages = with pkgs; [
    tdesktop
    calibre
  ];
}
