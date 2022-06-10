{ pkgs, options, ... }:

{
  time.timeZone = "Europe/Madrid";

  # Add any additional mount points per host
  fileSystems = options.fileSystems;

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
