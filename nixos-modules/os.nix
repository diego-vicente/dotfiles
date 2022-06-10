{ pkgs, options }:

{
  # Ensure that the TTY has the same layout as the X server
  console.useXkbConfig = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Enable automatic updates of the system
  system.autoUpgrade = {
    persistent = true;
    enable = options.updates.enable;
    dates = options.updates.date;
    allowReboot = false;
  };

  # Optimize the nix store by default for new derivations
  nix.autoOptimiseStore = true;

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
