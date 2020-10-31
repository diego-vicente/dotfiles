args@{ config, lib, pkgs, hostname, hostSpecific, ... }:

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
      ./hardware-configuration/vostok.nix
      # Include the home-manager channel
      <home-manager/nixos>
    ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    # loader.systemd-boot.enable = true;

    loader.efi.canTouchEfiVariables = true;

    loader.grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      configurationLimit = 30;
      useOSProber = true;
    };

    # FIXME: None of these flags work properly yet
    kernelParams = [
      # Configure the kernel to use the ACPI controls (Dell XPS 15 9560
      # specific)
      "pcie_port_pm=off"
      "acpi_backlight=vendor"
      "acpi_osi=Linux"
      "acpi_osi=!"
      ''acpi_osi="Windows 2009"''
      # Enable the DZ60RGB ANSI v2 PCB to be used during boot. Without this flag
      # the keyboard works fine but there cannot be used to select the boot
      # method. This fix is not general, but this is the way to infer it:
      #   1. `0x445a:0x1221` is the vendor and device ID. This will tell which
      #      device gets affected by the flag. This information is given by the
      #      `lsusb` command - just remember to add the 0x prefixes!
      #   2. `0x20000408` is a stack of flags. This is general and probably
      #      fixes similar problems, searching for it on the internet returns
      #      plenty examples. The actual flags are:
      #        #define HID_QUIRK_NOGET 0x00000008
      #        #define HID_QUIRK_ALWAYS_POLL 0x00000400
      #        #define HID_QUIRK_NO_INIT_REPORTS 0x20000000
      "usbhid.quirks=0x445a:0x1221:0x20000408"
    ];
  };

  # Allow non-free packages and include the unstable channel
  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      unstable = import <nixpkgs-unstable> {
        config = config.nixpkgs.config;
      };
    };
  };

  # Enable both GPUs using NVIDIA PRIME (offload mode). It is important to set the
  # correct xserver.videoDrivers as well as using the nvidia-offload script
  hardware.nvidia.prime = {
    offload.enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  # Define your hostname.
  networking.hostName = hostname;

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
  networking.interfaces.${hostSpecific.network.wireless}.useDHCP = true;

  # Disable IPv6 for now due to some router hiccups
  networking.enableIPv6 = false;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # Most of the packages are installed via home-manager to be used as well in
  # non-NixOS machines.
  environment.systemPackages = with pkgs; [
    # Power management
    powertop
    # tlp
    # USB/GPU/PCI utils
    usbutils
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
    # Scripting notifications utility
    libnotify
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

  # Enable TLP for power management
  services.tlp = {
    enable = true;
    # settings = {};
  };

  # Enable a basic i3 environment
  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    # No display manager, only i3 (managed by home-manager)
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
    shell = pkgs.zsh;
  };

  # home-manager configuration
  home-manager.users.dvicente = import ./home.nix (args // { inherit hostname; });

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
  system.stateVersion = "20.09"; # Did you read the comment?
}
