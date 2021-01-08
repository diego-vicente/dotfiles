{ config, lib, pkgs, hostname, ... }:

{
  imports = [ (../hardware-configuration + "/${hostname}.nix" ) ];

  environment.systemPackages = with pkgs; [
    # USB devices information
    usbutils
    # Filesystem and compression utilities
    ntfs3g
    zip
    unzip
  ];
}
