{ config, lib, pkgs, ... }:

{
  # This user configuration is designed to be static, therefore commands like
  # `passwd` will not work.
  users.mutableUsers = true;

  users.users.dvicente = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "video" "audio" ];
    shell = pkgs.zsh;
  };
}
