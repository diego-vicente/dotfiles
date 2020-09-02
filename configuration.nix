{ config, lib, pkgs, ... }:

let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec -a "$0" "$@"
  '';
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Include the home-manager channel
      <home-manager/nixos>
    ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelParams = [ "acpi_backlight=vendor" ];
  };

  networking.hostName = "vostok"; # Define your hostname.

  # TODO: NVIDIA PRIME support is to be included in 20.09
  # Enable both GPUs using NVIDIA PRIME (offload mode). It is important to set the
  # correct xserver.videoDrivers as well as using the nvidia-offload script
  # hardware.nvidia.prime = {
  #   offload.enable = true;
  #   intelBusId = "PCI:0:2:0";
  #   nvidiaBusId = "PCI:1:0:0";
  # };

  # Networking is managed by NetworkManager
  networking.networkmanager.enable = true;

  # Set the firewall to allow ICMP traffic
  networking.firewall = {
    enable = true;
    allowPing = true;
    # allowedTCPPorts = [ ... ];
    # allowedUDPPorts = [ ... ];
  };

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.wlp2s0.useDHCP = true;

  # Disable IPv6 for now due to some router hiccups
  networking.enableIPv6 = false;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # Most of the packages are installed via home-manager to be used as well in
  # non-NixOS machines.
  environment.systemPackages = with pkgs; [
    # GPU/PCI utils
    pciutils
    nvidia-offload
    # Thermal inforamtion
    lm_sensors
    # Audio settings
    flac
    pavucontrol
    # Filesystem and compression utilities
    ntfs3g
    unzip
  ];

  # Enable GnuPG. For now, it does not control the SSH identities.
  programs.gnupg.agent = {
    enable = true;
    # enableSSHSupport = true;
    pinentryFlavor = "gnome3";
  };

  # Enable the SSH agent.
  programs.ssh = {
    startAgent = true;
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
  };

  # Enable a basic i3 environment
  services.xserver = {
    enable = true;
    # videoDrivers = [ "nvidia" ];
    # No display manager, only i3
    displayManager.defaultSession = "none+i3";
    # Set i3 to i3-gaps and include other useful packages
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps;
      extraPackages = with pkgs; [ hsetroot ];
    };
    # Set the keyboard to US international
    layout = "us";
    xkbVariant = "intl";
    # Swap caps lock to control
    xkbOptions = "ctrl:nocaps";
    # Enable natural scrolling in X
    libinput = {
      enable = true;
      naturalScrolling = true;
    };
  };

  # Ensure that the TTY has the same layout as the X server
  console.useXkbConfig = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # Define the users account. Notice that this configuration has no mutable
  # users, so the user management must be done using this configuration only;
  # commands like `passwd` will not work.
  users.mutableUsers = false;
  users.users.dvicente = {
    isNormalUser = true;
    hashedPassword = "$6$MfPm2K7n0c$yMVhZX1pU8WS6bZS9PY5H8Ant6YltLnYn7jlOcyzeqHL3q8Gjwy4WeC1SI7EmGqzs15viBpIeJijBgTtUqVO3.";
    extraGroups = [ "wheel" "networkmanager" "input" "video" "audio" ]; # Enable ‘sudo’ for the user.
  };

  # home-manager configuration
  home-manager.users.dvicente = { pkgs, ... }: {
    # home.sessionVariables = {
    #   XDG_CONFIG_HOME = "$HOME/.config";
    # };
    xdg.enable = true;

    # TODO: include the modern tools in the declaration
    home.packages = with pkgs; [
      git wget curl rofi rxvt-unicode firefox vim ripgrep ranger
    ];

    programs.bash.enable = true;

    # TODO: investigate the configuration possibilities
    programs.firefox = {
      enable = true;
    };

    # Enable and configure the git user
    programs.git = {
      enable = true;
      userName = "Diego Vicente";
      userEmail = "mail@diego.codes";
    };

    # Emacs configuration
    programs.emacs = {
      enable = true;
      extraPackages = epkgs: [ epkgs.emacs-libvterm ];
    };

    services.emacs = {
      enable = true;
    };

    home.file.".doom.d" = {
      source = /home/dvicente/etc/dvm-emacs;
      recursive = true;
      onChange = builtins.readFile /home/dvicente/etc/dvm-emacs/bin/reload;
    };

    # Configure notification using dunst
    services.dunst = {
      enable = true;
      settings = {
        global = {
          follow = "mouse";
          geometry = "300x5-30+20";
          shrink = "no";
          transparency = 0;
          notification_height = 0;
          separator_height = 2;
          padding = 8;
          horizontal_padding = 8;
          frame_width = 3;
          frame_color = "#aaaaaa";
          separator_color = "frame";
          sort = "yes";
          idle_threshold = 120;
          font = "Iosevka 11";
          line_height = 0;
          format = "<b>%s</b>\n%b";
          alignment = "left";
          show_age_threshold = 60;
          stack_duplicates = true;
          hide_duplicate_count = false;
          show_indicators = "yes";
          icon_position = "off";
          sticky_history = "yes";
          history_length = 20;
        };
        urgency_low = {
          background = "#282828";
          foreground = "#fdf4c1";
          frame_color = "#fdf4c1";
          timeout = 10;
        };
        urgency_normal = {
          background = "#282828";
          foreground = "#fdf4c1";
          frame_color = "#fabd2f";
          timeout = 10;
        };
        urgency_critical = {
          background = "#282828";
          foreground = "#fdf4c1";
          frame_color = "#fb4934";
          timeout = 0;
        };
      };
    };

    # Configure rofi as the main launcher
    programs.rofi = {
      enable = true;
      theme = ./vostok/rofi/nord.rasi;
      font = "Iosevka 11";
      extraConfig = ''rofi.display-drun: Open'';
    };

    # Use Picom as compositor (mainly to prevent screen tearing)
    services.picom = {
      enable = true;
      shadow = false;
      vSync = true;
      fade = true;
      fadeDelta = 5;
      fadeSteps = [ "0.1" "0.1" ];
    };

    # Use polybar in i3
    services.polybar = {
      enable = true;
      package = with pkgs; polybar.override {
        i3Support = true;
      };
      config = ./vostok/polybar/config;
      script = ''
        PATH=$PATH:${pkgs.i3} polybar bar-laptop &
        PATH=$PATH:${pkgs.i3} polybar bar-hdmi &
      '';
    };

    # Set up other configuration files
    xdg.configFile = {
      "i3/config".source = ./vostok/i3/config;
      # "rofi/" = {
      #   source = ./vostok/rofi;
      #   recursive = true;
      # };
    };

    home.file = {
      ".Xresources".source = ./vostok/X/Xresources;
    };
  };

  fonts = {
    enableFontDir = true;
    fonts = with pkgs; [
      iosevka
      font-awesome
      noto-fonts-emoji
    ];
    fontconfig.defaultFonts.emoji = [ "Noto Color Emoji" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.03"; # Did you read the comment?
}
