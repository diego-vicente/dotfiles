{ config, lib, pkgs, ... }:

{
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      iosevka
      font-awesome
      noto-fonts-emoji
    ];
    fontconfig.defaultFonts.emoji = [ "Noto Color Emoji" ];
  };
}
