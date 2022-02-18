
{ config, lib, pkgs, emacsPkg, hostSpecific, ... }:

{
  home.packages = with pkgs; [
    # The unstable version provides a rolling release
    unstable.vscode
    # Other dependencies for the editor
    rnix-lsp
  ];
  
  # The settings for the editor itself are soft-linked and not included in the
  # home-manager derivation, to be able to use the settings menu included.
}