{ config, lib, pkgs, emacsPkg ? pkgs.emacs, ... }:

{
  # Emacs configuration
  programs.emacs = {
    enable = true;
    package = emacsPkg;
    extraPackages = epkgs: [
      epkgs.vterm
      epkgs.emacsql-sqlite
    ];
  };

  services.emacs = {
    enable = true;
  };

  home.packages = with pkgs; [
    # Required for IRC in doom-emacs
    gnutls
    # Dictionaries for emacs
    aspell
    aspellDicts.en
    aspellDicts.es
  ];
}
