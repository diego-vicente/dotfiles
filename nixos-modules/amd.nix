{ ... }:

{
  # Enable the correct modules
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Set the X drivers
  services.xserver.videoDrivers = [ "amdgpu" ];
}
