{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    teams
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
  ];
}
