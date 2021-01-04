# Bootstrap for the vostok host - it adds the correct hostname to the argument
# set that is passed to the configuration.nix file as well as all the hostname
# specific options to take into account.
# Expected use:
#   $ sudo ln -s ./bootstrap/vostok.nix /etc/nixos/configuration.nix
args@{ config, lib, pkgs, ... }:

let
  additionalArgs = {
    hostname = "vostok";
    hostSpecific = {
      # The video output names and its xrandr arguments
      video = {
        laptop = {
          output = "eDP-1";
          xrandrArgs = "--mode 1920x1080 --rotate normal";
        };
        hdmi = {
          output = "HDMI-1";
          xrandrArgs = ''--mode 2560x1440 --rotate normal --set "Broadcast RGB" "Full"'';
        };
        pci = {
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
      # Network interfaces names
      network = {
        wireless = "wlp2s0";
        ethernet = "enp62s0u1u2";
      };
      # Temperature sensors to be used with lm-sensors
      temperature = {
        package = "/sys/devices/platform/coretemp.0/hwmon/hwmon5/temp1_input";
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
            profile = "hdmi-stereo";
            port = "hdmi-output";
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
  import ../configuration.nix extendedArgs
