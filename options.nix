{
  # This set of options define all host-specific behavior so that a single
  # configuration can fit all my machines. 
  soyuz = {
    # Soyuz is a Dell XPS 15 9570 that I use for work.
    nixos = {
      # Do not change this version unless active action has been taken since
      # installation. Remember that updating the flake is done by modifying the
      # inputs; this just defines how some stateful configuration should be
      # parsed.
      configuration.stateVersion = "21.11";
      # Configure filesystem definition and some software to interact with the
      # machine's hardware.
      hardware = {
        fileSystems = { };  # No filesystems are to be mounted by default.
      };
      # Configure the boot settings and other GRUB related aspects. 
      boot = {
        maxGenerations = 10;
      };
      # Configure the OS-related services.
      os = {
        # TODO: convert updates to flakes properly
        updates = {
          enable = false;
          date = "Fri *-*-* 16:00:00";
        };
      };
      # Configure networking interfaces and tools.
      networking = {
        hostname = "soyuz";
        wireless = "wlp59s0";
      };
      # Configure the GPG setup.
      gpg = { };
      # Enable SSH.
      ssh = { };
      # Define the basic users (more in the home-manager config).
      users = { };
      # Set up backups using Borgbase repositories.
      backup = {
        paths = [ "/home" ];
        exclude = [
          "/home/*/usb"
          "/home/*/lib"
        ];
        borgbaseRepo = "k6vw052b@k6vw052b.repo.borgbase.com:repo";
        schedule = "14:00";
      };
      # Set up the X server session and other interaction tools.
      xserver = { };
      # Define the default fonts for the system.
      fonts = { };
      # Set up the Nvidia graphics card.
      nvidia = {
        pci = {
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
      # Enable Docker.
      docker = { };
    };

    homeManager = {
      # Set up and install the basic CLI tools that I use.
      cli = { 
        info = {
          userName = "diego vicente";
          userEmail = "diego.vicente@decidesoluciones.es";
        };
      };
      # Define the graphical user interface and the keyboard shortcuts that I
      # use.
      gui = { };
      # Set up the webcam.
      webcam = { device = "/dev/video2"; };
      # Set up the keyboard.
      keyboard = { };
      # Install Visual Studio Code and other complements.
      vscode = { };
      # Install some program I need at work.
      work = { };
    };
  };

  korolev = {
    nixos = {
      # Do not change this version unless active action has been taken since
      # installation. Remember that updating the flake is done by modifying the
      # inputs; this just defines how some stateful configuration should be
      # parsed.
      configuration.stateVersion = "21.11";
      # Configure filesystem definition and some software to interact with the
      # machine's hardware.
      hardware = {
        fileSystems = { 
          # Add the media NVME mounted in /mnt/media
          "/mnt/media" = {
            device = "/dev/nvme1n1p2";
            fsType = "ntfs";
            # options = [ "data=journal" ];
          };
        };
      };
      # Configure the boot settings and other GRUB related aspects. 
      boot = {
        maxGenerations = 2;  # Due to a small /boot partition
      };
      # Configure the OS-related services.
      os = {
        # TODO: convert it to flakes properly
        updates = {
          enable = false;
          date = "Sun *-*-* 14:30:00";
        };
      };
      # Configure networking interfaces and tools.
      networking = {
        hostname = "korolev";
        wireless = "wlp6s0";
        ethernet = "enp7s0";
      };
      # Configure the GPG setup.
      gpg = { };
      # Enable SSH.
      ssh = { };
      # Define the basic users (more in the home-manager config).
      users = { };
      # Set up backups using Borgbase repositories.
      backup = {
        paths = [
          "/home"
          "/mnt/media"
        ];
        exclude = [
          "/home/*/usb"
          "/home/*/lib"
          "/mnt/media/games"
        ];
        borgbaseRepo = "mz2by24z@mz2by24z.repo.borgbase.com:repo";
        schedule = "14:15";
      };
      # Set up the X server session and other interaction tools.
      xserver = { };
      # Define the default fonts for the system.
      fonts = { };
      # Set up the AMD graphics card.
      amd = { };
    };

    homeManager = {
      # Set up and install the basic CLI tools that I use.
      cli = { 
        info = {
          userName = "Diego Vicente";
          userEmail = "mail@diego.codes";
        };
      };
      # Define the graphical user interface and the keyboard shortcuts that I
      # use.
      gui = { };
      # Set up the webcam.
      webcam = { device = "/dev/video0"; };
      # Set up the keyboard.
      keyboard = { };
      # Install Visual Studio Code and other complements.
      vscode = { };
      # Install the photography programs.
      photography = { };
    };
  };

  # Vostok is my personal Dell XPS 15 9560
  vostok = {
    nixos = {
      # Do not change this version unless active action has been taken since
      # installation. Remember that updating the flake is done by modifying the
      # inputs; this just defines how some stateful configuration should be
      # parsed.
      configuration.stateVersion = "21.05";
      # Configure filesystem definition and some software to interact with the
      # machine's hardware.
      hardware = {
        fileSystems = { };  # No filesystems are to be mounted by default.
      };
      # Configure the boot settings and other GRUB related aspects. 
      boot = {
        maxGenerations = 10;
      };
      # Configure the OS-related services.
      os = {
        # TODO: convert updates to flakes properly
        updates = {
          enable = false;
          date = "*-*-* 13:00:00";
        };
      };
      # Configure networking interfaces and tools.
      networking = {
        hostname = "vostok";
        wireless = "wlp2s0";
      };
      # Configure the GPG setup.
      gpg = { };
      # Enable SSH.
      ssh = { };
      # Define the basic users (more in the home-manager config).
      users = { };
      # Set up backups using Borgbase repositories.
      backup = {
        paths = [ "/home" ];
        exclude = [ "/home/*/usb" ];
        borgbaseRepo = "vd67iwa5@vd67iwa5.repo.borgbase.com:repo";
        schedule = "12:00";
      };
      # Set up the X server session and other interaction tools.
      xserver = { };
      # Define the default fonts for the system.
      fonts = { };
      # Set up the Nvidia graphics card.
      nvidia = {
        pci = {
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
    };

    homeManager = {
      # Set up and install the basic CLI tools that I use.
      cli = { 
        info = {
          userName = "diego vicente";
          userEmail = "mail@diego.codes";
        };
      };
      # Define the graphical user interface and the keyboard shortcuts that I
      # use.
      gui = { };
      # Set up the webcam.
      webcam = { device = "/dev/video2"; };
      # Set up the keyboard.
      keyboard = { };
      # Install Visual Studio Code and other complements.
      vscode = { };
    };
  };
}