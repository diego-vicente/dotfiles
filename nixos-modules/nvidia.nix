{ config, lib, pkgs, hostSpecific, ... }:

{
  boot = {
    kernelParams = [
      "acpi_osi=Linux"
      "acpi_rev_override=1"
      "mem_sleep_default=deep"
      "intel_iommu=igfx_off"
    ];
    kernelPackages = pkgs.linuxPackages_5_4;
    extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
    blacklistedKernelModules = [ "nouveau "];
  };
  
  services.xserver = {
    videoDrivers = [ 
      "nvidia" 
    ];
  };

  # Add the drivers and additional tools
  environment.systemPackages = [
    pkgs.pciutils
  ];

  hardware.opengl = {
    driSupport = true;
    driSupport32Bit = true;
  };

  hardware.nvidia = with hostSpecific.video.pci; {
    modesetting.enable = true;
    prime = {
      sync.enable = true;
      intelBusId = intelBusId;
      nvidiaBusId = nvidiaBusId;
    };
  };
}
