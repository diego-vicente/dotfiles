# Bootstrap for the vostok host - it adds the correct hostname to the argument
# set that is passed to the configuration.nix file as well as all the hostname
# specific options to take into account.
# Expected use:
#   $ ln -s ./bootstrap/soyuz.nix ~/.config/nixpkgs/home.nix
args@{ config, lib, pkgs, ... }:

let
  additionalArgs = {
    hostname = "soyuz";
    hostSpecific = {
      # The video output names and its xrandr arguments
      video = {
        laptop = {
          output = "eDP1";
          xrandrArgs = "--mode 1920x1080 --rotate normal";
        };
        hdmi = {
          output = "HDMI1";
          xrandrArgs = ''--mode 2560x1440 --rotate normal --set "Broadcast RGB" "Full"'';
        };
      };
      # Network interfaces names
      network = {
        wireless = "wlp2s0";
        ethernet = "enp62s0u1u2";
      };
      # Temperature sensors to be used with lm-sensors
      temperature = {
        package = "/sys/devices/virtual/hwmon/hwmon3/temp1_input";
      };
      # Audio profiles, sinks and ports to be used with pactl/pacmd
      audio = rec {
        laptop = {
          output = {
            profile = "analog-stereo";
            port = "analog-output-speaker";
          };
          input = {
            profile = "analog-stereo";
            port = "analog-input-internal-mic";
          };
        };
        hdmi = {
          output = {
            profile = "hdmi-stereo-extra2";
            port = "hdmi-output-2";
          };
          input = laptop.input;
        };
        headphones = {
          output = {
            profile = "analog-stereo";
            port = "analog-output-headphones";
          };
          input = {
            profile = "analog-stereo";
            port = "analog-input-headset-mic";
          };
        };
      };
    };
  };
  extendedArgs = args // additionalArgs;
in
  import ../home.nix extendedArgs
