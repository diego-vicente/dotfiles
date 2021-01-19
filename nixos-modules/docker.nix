{ config, lib, pkgs, ... }:

{
  # Enable the Docker service
  virtualisation.docker.enable = true;

  # Give access to the user
  users.users.dvicente.extraGroups = [ "docker" ];
}
