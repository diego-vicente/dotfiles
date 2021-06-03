{ config, lib, pkgs, ... }:

let
  # FIXME: import this via top level arguments
  unstable =  import <nixpkgs-unstable> {};
in {
  # As suggested by @ryantm in the NixOS Discourse
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # As suggested by @Seebi in the NixOS Discourse 
  # hardware.opengl = {
  #   enable = true;
  #   package = unstable.mesa.drivers;
  #   driSupport32Bit = true;
  #   package32 = unstable.pkgsi686Linux.mesa.drivers;
  # };

  # As suggested by @afontaine in the NixOS Discourse
  # boot.kernelPatches = [
  #   {
  #     name = "big-navi";
  #     patch = null;
  #     extraConfig = ''
  #       DRM_AMD_DC_DCN3_0 y
  #    '';
  #   }
  # ];
  # Enable the correct modules
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Set the X drivers
  services.xserver.videoDrivers = [ "amdgpu" ];
}
