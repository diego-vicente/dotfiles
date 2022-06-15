{ pkgs, nixosOptions, ... }:

{
  time.timeZone = "Europe/Madrid";

  # Add any additional mount points per host
  fileSystems = nixosOptions.hardware.fileSystems;

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
