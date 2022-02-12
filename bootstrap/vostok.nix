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
      info = {
        # --- Basic user information ---
        # This set contains some general information to be associated with each
        # machine. For example, the name and email here will the the one used by
        # default in git commits across the system.
        userName = "Diego Vicente";
        userEmail = "mail@diego.codes";
      };
      updates = {
        # Define the autoupdate settings for this host.
        enable = true;
        date = "*-*-* 13:00:00";
      };
      backup = {
        # Please check nixos-modules/backup.nix for specific instructions on
        # how to initialize a new repository in a new host!
        paths = [ "/home" ];
        exclude = [ "/home/*/usb" ];
        borgbaseRepo = "vd67iwa5@vd67iwa5.repo.borgbase.com:repo";
        schedule = "12:00";
      };
      boot = {
        maxGenerations = 10;
      };
      fileSystems = {};
      video = {
        # --- Video outputs ---
        # The output names differ from one system to another and can be checked
        # using:
        #   $ xrandr
        # If the setup is the same, the same `xrandrArgs` should be valid from
        # one system to another.
        strategy = "nvidia-offload";
        main = {
          name = "laptop";
          output = "eDP-1";
          xrandrArgs = "--mode 1920x1080 --rotate normal";
        };
        aux = {
          name = "HDMI";
          output = "HDMI-1";
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
        wireless = "wlp2s0";
        ethernet = "enp62s0u1u2";
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
          name = "laptop";
          output = {
            profile = "analog-stereo";
            port = "analog-output-speaker";
          };
          input = {
            profile = "analog-stereo";
            port = "analog-input-internal-mic";
          };
        };
        aux = {
          name = "HDMI";
          output = {
            profile = "hdmi-stereo";
            port = "hdmi-output";
          };
          input = main.input;
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
      };
    };
  };
  extendedArgs = args // additionalArgs;
in
  import ../configuration.nix extendedArgs
