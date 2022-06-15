{ pkgs, ... }:

{
  # Enable TLP for power management
  services.tlp = {
    enable = true;
    # settings = {};
  };

  # Add utils to monitor power consumption
  environment.systemPackages = with pkgs; [
    powertop
    lm_sensors
  ];
}
