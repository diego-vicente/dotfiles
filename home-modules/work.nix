{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    teams
    libreoffice
    dbeaver
    postman
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
  ];
}
