{ config, lib, pkgs, ... }:

{
  # Enable TLP for power management
  services.tlp = {
    enable = true;
    # settings = {};
  };

  # Ensure that the TTY has the same layout as the X server
  console.useXkbConfig = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Add utils to monitor power consumption
  environment.systemPackages = with pkgs; [
    powertop
    lm_sensors
  ];
}
