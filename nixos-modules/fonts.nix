{ config, lib, pkgs, ... }:

{
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      noto-fonts
      noto-fonts-emoji
      jetbrains-mono
      font-awesome
      emacs-all-the-icons-fonts
      (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    ];

    fontconfig = {
      defaultFonts = {
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        monospace = [ "JetBrainsMonoMedium Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
