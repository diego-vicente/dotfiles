{ config, lib, pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;
    # TODO: include extensions declaratively?
  };

  # Add a dekstop entry for Chrome that uses dark mode
  home.file.".local/share/applications/GoogleChrome.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Encoding=UTF-8
    Name=Google Chrome (Dark)
    # Generic name is presented only for my system
    GenericName=Web browser - dark mode
    Exec=${pkgs.google-chrome}/bin/google-chrome-stable --force-dark-mode %U
    StartupNotify=true
    Icon=google-chrome
    Categories=Network;WebBrowser;
    Terminal=false
    MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;

    # Desktop actions are not implemented since I don't use them in my setup
  '';
}
