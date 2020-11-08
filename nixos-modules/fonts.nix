{ config, lib, pkgs, ... }:

{
  fonts = {
    enableFontDir = true;
    fonts = with pkgs; [
      iosevka
      font-awesome
      noto-fonts-emoji
    ];
    fontconfig.defaultFonts.emoji = [ "Noto Color Emoji" ];
  };
}
