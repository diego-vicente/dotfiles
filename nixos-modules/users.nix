{ config, lib, pkgs, ... }:

{
  # This user configuration is designed to be static, therefore commands like
  # `passwd` will not work.
  users.mutableUsers = false;

  users.users.dvicente = {
    isNormalUser = true;
    hashedPassword = "$6$MfPm2K7n0c$yMVhZX1pU8WS6bZS9PY5H8Ant6YltLnYn7jlOcyzeqHL3q8Gjwy4WeC1SI7EmGqzs15viBpIeJijBgTtUqVO3.";
    extraGroups = [ "wheel" "networkmanager" "input" "video" "audio" ];
    shell = pkgs.zsh;
  };
}
