{ config, lib, pkgs, ... }:

{
  # This X configuration is designed to delegate all the session specifics like
  # i3 or polybar to the home-manager (and therefore, per-user) configuration
  services.xserver = {
    enable = true;
    # Delegate the session on the home-manager script
    desktopManager.session = [
      {
        name = "home-manager";
        start = ''
          ${pkgs.runtimeShell} $HOME/.hm-xsession &
          waitPID=$!
        '';
      }
    ];
    # # Set the keyboard to US international
    layout = "us";
    xkbVariant = "intl";
    # Swap caps lock to control
    xkbOptions = "ctrl:nocaps";
    # Enable natural scrolling in X (only for touchpads)
    libinput = {
      enable = true;
      naturalScrolling = true;
      additionalOptions = ''MatchIsTouchpad "on"'';
    };
  };

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
