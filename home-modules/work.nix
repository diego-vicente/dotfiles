{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    teams
    libreoffice
    dbeaver
    gnome.networkmanager-openvpn
  ];
}
