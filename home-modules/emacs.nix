{ config, lib, pkgs, emacsPkg ? pkgs.emacs, ... }:

{
  # Emacs configuration
  programs.emacs = {
    enable = true;
    package = emacsPkg;
    extraPackages = epkgs: [
      epkgs.vterm
    ];
  };

  services.emacs = {
    enable = true;
  };

  # home.file.".emacs.d" = {
  #   source =
  #   recursive = true;
  # };

  # Required for IRC in doom-emacs
  home.packages = with pkgs; [
    gnutls
    aspell
    aspellDicts.en
    aspellDicts.es
  ];
}
