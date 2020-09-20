{ config, lib, pkgs, ... }:

{
  # TODO: Check if there is a way to set Firefox Sync
  programs.firefox = {
    enable = true;
    profiles.personal = {
      settings = {
        "browser.search.region" = "US";
        "browser.bookmarks.showMobileBookmarks" = true;
        "browser.fullscreen.autohide" = false;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.download.dir" = "~/docs/downloads";
        "browswer.download.folderList" = 2;
        "browser.aboutConfig.showWarning" = false;
        "sidebar.position_start" = false;
        # Recommended by Tree Style Tab settings
        "svg.context-properties.content.enabled" = true;
      };
      userChrome = builtins.readFile ../assets/userChrome.css;
    };
  };
}
