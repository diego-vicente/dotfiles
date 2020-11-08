{ config, lib, pkgs, hostname, ... }:

{
  # FIXME: make hostname-dependant import
  imports = [ ../hardware-configuration/vostok.nix ];

  environment.systemPackages = with pkgs; [
    # USB devices information
    usbutils
    # Filesystem and compression utilities
    ntfs3g
    unzip
  ];
}
