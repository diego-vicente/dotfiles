{ config, lib, pkgs, ... }:

{
  # This X configuration is designed to delegate all the session specifics like
  # i3 or polybar to the home-manager (and therefore, per-user) configuration
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    displayManager.gdm.wayland = false;
    desktopManager.gnome.enable = true;
    # Set the keyboard to US international
    layout = "us";
    xkbVariant = "intl";
    # Swap caps lock to control
    xkbOptions = "ctrl:nocaps";
    # Enable natural scrolling in X (only for touchpads)
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
      };
    };
  };

  # Enable proper Gnome configuration via Nix/home-manager
  services.dbus.packages = with pkgs; [ gnome.dconf ];
  services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];

  # Sound is enabled for systems with X
  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
  };

  # Add the basic GUI and sound packages for the system
  environment.systemPackages = with pkgs; [
    # Scripting notifications utility
    libnotify
    # Audio settings
    flac
    pavucontrol
  ];
}
