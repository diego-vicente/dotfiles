# Bootstrap for the korolev host - it adds the correct hostname to the argument
# set that is passed to the configuration.nix file as well as all the hostname
# specific options to take into account.
# Expected use:
#   $ sudo ln -s ./bootstrap/korolev.nix /etc/nixos/configuration.nix
args@{ config, lib, pkgs, ... }:

let
  additionalArgs = {
    hostname = "korolev";
    hostSpecific = {
      info = {
        # --- Basic user information ---
        # This set contains some general information to be associated with each
        # machine. For example, the name and email here will the the one used by
        # default in git commits across the system.
        userName = "Diego Vicente";
        userEmail = "mail@diego.codes";
        # The BorgBase repo is only needed if nixos-modules/backup.nix is active
        # borgbaseRepo = "k6vw052b@k6vw052b.repo.borgbase.com:repo";
        # backupSchedule = "14:00";
      };
      video = {
        # --- Video outputs ---
        # The output names differ from one system to another and can be checked
        # using:
        #   $ xrandr
        # If the setup is the same, the same `xrandrArgs` should be valid from
        # one system to another.
        laptop = {
          output = "HDMI-A-0";
          xrandrArgs = ''--mode 2560x1440 --rotate normal --set "Broadcast RGB" "Full"'';
        };
        hdmi = {
          output = "DP-3";
          xrandrArgs = ''--mode 2560x1440 --rotate normal --set "Broadcast RGB" "Full"'';
        };
      };
      network = {
        # --- Network interfaces ---
        # Which network interfaces are available. It is quite easy to see all of
        # them using:
        #   $ ifconfig -a
        wireless = "wlp6s0";
        ethernet = "enp7s0";
      };
      temperature = {
        # --- Temperature sensors ---
        # Find the package temperature to be displayed on the bar using
        # `sensors` to see the appropriate measurement and then run the
        # following script to find the associated descriptor:
        #   $ for i in /sys/class/hwmon/hwmon*/temp*_input; do echo "$(<$(dirname $i)/name): $(cat ${i%_*}_label 2>/dev/null || echo $(basename ${i%_*})) $(readlink -f $i)"; done
        package = "/sys/devices/platform/coretemp.0/hwmon/hwmon5/temp1_input";
      };
      audio = rec {
        # --- Audio profiles ---
        # To check the name of the available, I recommend using `pavucontrol` to
        # check the working outputs for each system and then trying to locate
        # the proper profile and port name using `grep` and some elbow grease on
        # its output:
        #   $ pacmd list
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
  import ../configuration.nix extendedArgs