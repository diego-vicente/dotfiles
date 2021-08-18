{ config, lib, pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;
    # TODO: include extensions declaratively?
  };
}
