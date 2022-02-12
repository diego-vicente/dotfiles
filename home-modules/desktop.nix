{ config, lib, pkgs, unstable, ... }:

{
  # Install other desktop apps without in depth-configuration.
  home.packages = with pkgs; [
    calibre
    # Gnome 3 Apps
    gnome.eog
    gnome.rygel
    gnome.mutter
    gnome.gpaste
    gnome.cheese
    gnome.nautilus
    gnome.sushi
    gnome.file-roller
    gnome.gnome-music
    gnome.gnome-tweaks
    gnome.gnome-calendar
    gnome.dconf-editor
    gnomeExtensions.user-themes
    gnomeExtensions.paperwm
    # Rolling release apps
    unstable.rmview
    unstable.vscode
  ];
}
