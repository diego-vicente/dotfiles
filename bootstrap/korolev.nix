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
        borgbaseRepo = "mz2by24z@mz2by24z.repo.borgbase.com:repo";
        backupSchedule = "21:00";
      fileSystems = {
        # Add the media NVME mounted in /mnt/media
        "/mnt/media" = {
          device = "/dev/nvme1n1p2";
          fsType = "ntfs";
          # options = [ "data=journal" ];
        };
      };
      video = {
        # --- Video outputs ---
        # The output names differ from one system to another and can be checked
        # using:
        #   $ xrandr
        # If the setup is the same, the same `xrandrArgs` should be valid from
        # one system to another.
        main = {
          name = "screen";
          output = "HDMI-A-0";
          xrandrArgs = ''--mode 2560x1440 --rotate normal --set "Broadcast RGB" "Full"'';
        };
        aux = null;
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
        main = {
          name = "screen";
          output = {
            profile = "analog-stereo";
            port = "analog-output-speaker";
          };
          input = {
            profile = "analog-stereo";
            port = "analog-input-internal-mic";
          };
        };
        headphones = {
          name = "headphones";
          output = {
            profile = "analog-stereo";
            port = "analog-output-headphones";
          };
          input = {
            profile = "analog-stereo";
            port = "analog-input-headset-mic";
          };
        };
        aux = null;
      };
    };
  };
  extendedArgs = args // additionalArgs;
in
  import ../configuration.nix extendedArgs
