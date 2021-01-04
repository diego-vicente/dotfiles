{ config, lib, pkgs, hostSpecific, ... }:

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
  # Set the X drivers
  services.xserver.videoDrivers = [ "nvidia" ];

  # Enable both GPUs using NVIDIA PRIME (offload mode)
  hardware.nvidia.prime = with hostSpecific.video.pci; {
    offload.enable = true;
    intelBusId = intelBusId;
    nvidiaBusId = nvidiaBusId;
  };

  # Add the drivers and additional tools
  environment.systemPackages = [
    pkgs.pciutils
    nvidia-offload
  ];
}
