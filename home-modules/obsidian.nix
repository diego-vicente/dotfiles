{ pkgs, homeOptions, ... }:

{
  home.packages = with pkgs; [
    obsidian              # To read the notes
    grive2 inotify-tools  # To sync google drive
  ];

  # To correctly configure grive for the first time:
  #   $ mkdir ~/google-drive
  #   $ cd ~/google-drive
  #   $ grive -a
  #   $ systemctl --user enable grive-changes@$(systemd-escape google-drive).service
  #   $ systemctl --user start grive-changes@$(systemd-escape google-drive).service
  #   $ systemctl --user enable grive-timer@$(systemd-escape google-drive).timer
  #   $ systemctl --user start grive-timer@$(systemd-escape google-drive).timer
}