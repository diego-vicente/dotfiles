{ config, lib, pkgs, ... }:

{
  # GOTCHA: This user configuration is designed to be mutable, therefore the
  # first step out of the box should be to run `sudo passwd $USER`.
  users.mutableUsers = true;

  users.users.dvicente = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "video" "audio" ];
    shell = pkgs.zsh;
  };
}
