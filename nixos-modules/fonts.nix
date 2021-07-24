{ config, lib, pkgs, ... }:

{
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      iosevka
      roboto
      roboto-mono
      font-awesome
      emacs-all-the-icons-fonts
      noto-fonts-emoji
    ];

    fontconfig.defaultFonts = {
      serif = [ "Roboto Slab" ];
      sansSerif = [ "Roboto" ];
      monospace = [ "Roboto Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
