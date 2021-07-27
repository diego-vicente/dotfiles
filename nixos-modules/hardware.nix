{ config, lib, pkgs, hostname, hostSpecific, ... }:

{
  imports = [ (../hardware-configuration + "/${hostname}.nix" ) ];

  time.timeZone = "Europe/Madrid";

  # Add any additional mount points per host
  fileSystems = hostSpecific.fileSystems;

  environment.systemPackages = with pkgs; [
    # USB devices information
    usbutils
    # Filesystem and compression utilities
    ntfs3g
    zip
    unzip
    unrar
  ];
}
