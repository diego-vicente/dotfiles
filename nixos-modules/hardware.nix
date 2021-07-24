{ config, lib, pkgs, hostname, ... }:

{
  imports = [ (../hardware-configuration + "/${hostname}.nix" ) ];

  time.timeZone = "Europe/Madrid";

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
