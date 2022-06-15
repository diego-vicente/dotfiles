{ pkgs, homeOptions, ... }:

{
  home.packages = with pkgs; [
    teams
    libreoffice
    dbeaver
    gnome.networkmanager-openvpn
  ];
}
