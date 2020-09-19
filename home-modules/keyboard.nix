{ config, lib, pkgs, ... }:

{
  # Cofnigure the keyboard to use US international with dead keys. This allows
  # to use tildes in Spanish while using the US layout. Also, always remap Caps
  # Lock to Ctrl.
  home.keyboard = {
    layout = "us";
    variant = "intl";
    options = [ "ctrl:nocaps" ];
  };
}
