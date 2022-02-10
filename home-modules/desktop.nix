{ config, lib, pkgs, unstable, ... }:

{
  # Install other desktop apps without in depth-configuration.
  home.packages = with pkgs; [
    chromium
    calibre
    unstable.rmview
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    unstable.vscode
  ];
}
