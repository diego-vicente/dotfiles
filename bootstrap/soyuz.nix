# Bootstrap for the soyuz host - it adds the correct hostname to the argument
# set that is passed to the configuration.nix file as well as all the hostname
# specific options to take into account.
# Expected use:
#   $ sudo ln -s ./bootstrap/soyuz.nix /etc/nixos/configuration.nix
args@{ config, lib, pkgs, ... }:

let
  additionalArgs = {
    hostname = "soyuz";
    hostSpecific = {
      info = {
        # --- Basic user information ---
        # This set contains some general information to be associated with each
        # machine. For example, the name and email here will the the one used by
        # default in git commits across the system.
        userName = "Diego Vicente";
        userEmail = "diego.vicente@decidesoluciones.es";
        # The BorgBase repo is only needed if nixos-modules/backup.nix is active
        borgbaseRepo = "k6vw052b@k6vw052b.repo.borgbase.com:repo";
        backupSchedule = "14:30";
      };
      video = {
        # --- Video outputs ---
        # The output names differ from one system to another and can be checked
        # using:
        #   $ xrandr
        # If the setup is the same, the same `xrandrArgs` should be valid from
        # one system to another.
        laptop = {
          output = "eDP-1-1";
          xrandrArgs = "--mode 1920x1080 --rotate normal";
        };
        hdmi = {
          output = "DP-1-3";
          xrandrArgs = ''--mode 2560x1440 --rotate normal --set "Broadcast RGB" "Full"'';
        };
        # --- PCI addresses ---
        # In order to use the NVidia Offload, the bus id must be given in a
        # special input. To check for the address, run:
        #   $ lspci
        # And check [1] to see the correct way to translate the address.
        #
        # [1]: https://nixos.wiki/wiki/Nvidia#offload_mode
        pci = {
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
      network = {
        # --- Network interfaces ---
        # Which network interfaces are available. It is quite easy to see all of
        # them using:
        #   $ ifconfig -a
        wireless = "wlp59s0";
        ethernet = "ens20u1u2";
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
