{ config, lib, pkgs, hostSpecific, ... }:

{
  # TODO: review if using flakes this could be done in a CI/CD environment to
  # be tested and stored.

  # Enable automatic updates of the system
  system.autoUpgrade = {
    enable = hostSpecific.updates.enable;
    dates = hostSpecific.updates.date;
    allowReboot = false;
  };

  # Enable regular garbage collection from the nix-store
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30";
  };

  # Also trigger garbage collection each time there is less than 100MiB left
  nix.extraOptions = ''
    min-free = ${toString (100 * 1024 * 1024)}
    max-free = ${toString (1024 * 1024 * 1024)}
  '';
}
