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

  home.file.".doom.d" = {
    source = /home/dvicente/etc/dvm-emacs;
    recursive = true;
    onChange = builtins.readFile /home/dvicente/etc/dvm-emacs/bin/reload;
  };

  # Required for IRC in doom-emacs
  home.packages = with pkgs; [
    gnutls
    aspell
    aspellDicts.en
    aspellDicts.es
  ];
}
