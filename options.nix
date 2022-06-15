{
  soyuz = {
    nixos = {
      configuration.stateVersion = "21.11";
      hardware = {
        fileSystems = { };
      };
      boot = {
        maxGenerations = 10;
      };
      os = {
        updates = {
          # TODO: convert it to flakes properly
          enable = false;
          date = "Fri *-*-* 16:00:00";
        };
      };
      networking = {
        hostname = "soyuz";
        wireless = "wlp59s0";
      };
      gpg = { };
      ssh = { };
      users = { };
      backup = {
        paths = [ "/home" ];
        exclude = [
          "/home/*/usb"
          "/home/*/lib"
        ];
        borgbaseRepo = "k6vw052b@k6vw052b.repo.borgbase.com:repo";
        schedule = "14:00";
      };
      xserver = { };
      fonts = { };
      nvidia = {
        pci = {
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
      docker = { };
    };

    homeManager = {
      cli = { 
        info = {
          userName = "diego vicente";
          userEmail = "diego.vicente@decidesoluciones.es";
        };
      };
      gui = { };
      webcam = { device = "/dev/video2"; };
      keyboard = { };
      # emacs = { };
      vscode = { };
      work = { };
    };
  };

  korolev = {
    nixos = {
      configuration.stateVersion = "21.11";
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
      boot = {
        maxGenerations = 2;  # Due to a small /boot partition
      };
      os = {
        updates = {
          # TODO: convert it to flakes properly
          enable = false;
          date = "Sun *-*-* 14:30:00";
        };
      };
      networking = {
        hostname = "korolev";
        wireless = "wlp6s0";
        ethernet = "enp7s0";
      };
      gpg = { };
      ssh = { };
      users = { };
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
      xserver = { };
      fonts = { };
      amd = { };
    };

    homeManager = {
      cli = { 
        info = {
          userName = "Diego Vicente";
          userEmail = "mail@diego.codes";
        };
      };
      gui = { };
      webcam = { device = "/dev/video0"; };
      keyboard = { };
      emacs = { };
      vscode = { };
      photography = { };
    };
  };
}