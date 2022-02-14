{ config, lib, pkgs, hostSpecific, ... }:

{
  boot = {
    kernelParams = [
      "acpi_osi=Linux"
      "acpi_rev_override=1"
      "mem_sleep_default=deep"
      "intel_iommu=igfx_off"
    ];
    kernelModules = [
      "kvm-intel"
      "nvidia"
    ];
    # extraModulePackages = [ 
    #   pkgs.linuxPackages.nvidia_x11
    # ];
    # blacklistedKernelModules = [ "nouveau" ];
  };
  
  services.xserver = {
    # Wayland is not compatible with this setup
    displayManager.gdm.wayland = lib.mkForce false;
    # Load both intel and NVidia drivers
    videoDrivers = [ 
      "intel"
      "nvidia" 
    ];
  };

  # Again, load all drivers even if they are not used
  hardware.opengl.extraPackages  = [
    pkgs.libGL_driver
    pkgs.linuxPackages.nvidia_x11.out
  ];

  # Configure the NVidia bus identification
  hardware.nvidia = with hostSpecific.video.pci; {
    modesetting.enable = true;
    prime = {
      # sync.enable = true;
      intelBusId = intelBusId;
      nvidiaBusId = nvidiaBusId;
    };
  };

  # Add the drivers and additional tools
  environment.systemPackages = [
    pkgs.pciutils
  ];
}
