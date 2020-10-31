{ config, lib, pkgs, unstable, ... }:

{
  home.packages = with pkgs; [
    vcv-rack
    orca-c
  ];

  # Add a desktop entry for GPU enabled VCV
  home.file.".local/share/applications/Rack.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Encoding=UTF-8
    Name=VCV Rack
    Comment=An open-source virtual module synthesizer.
    Exec=nvidia-offload ${pkgs.vcv-rack}/bin/Rack
    Icon=application.png
    Terminal=false
  '';
}
