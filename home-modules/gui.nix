{ config, lib, pkgs, emacsPkg, hostSpecific, ... }:

{
  # Install all GUI related packages
  home.packages = with pkgs; [
    # Gnome apps
    gnome.eog
    gnome.rygel
    gnome.mutter
    gnome.gpaste
    gnome.cheese
    gnome.nautilus
    gnome.sushi
    gnome.file-roller
    gnome.gnome-music
    gnome.gnome-tweaks
    gnome.gnome-calendar
    gnome.dconf-editor
    gnomeExtensions.user-themes
    gnomeExtensions.paperwm 
    # Other apps
    google-chrome  # GOTCHA: modified via nix-modules/overlays.nix
    calibre
    insomnia
    flameshot
    # Rolling release apps
    unstable.rmview
    unstable.vscode
  ];

  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "${../assets/caffeine.png}";
    };
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
      titlebar-font = "Noto Sans 11";
    };
    "org/gnome/desktop/interface" = {
      monospace-font-name = "JetBrains Mono Medium 10";
      document-font-name = "Noto Serif 11";
    };
    "org/gnome/shell" = {
      enabled-extensions = [
        "GPaste@gnome-shell-extensions.gnome.org"
        "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        # FIXME: tiling window manager is still not compatible with Gnome 40
        # "paperwm@hedning:matrix.org"
      ];
      favorite-apps = [
        "google-chrome.desktop"
        "code.desktop"
      ];
    };
    "org/gnome/shell/overrides" = {
      dynamic-workspaces = true;
      # These settings are not supported by PaperWM
      edge-tiling = false;
      workspaces-only-on-primary = false;
      attach-modal-dialogs = false;
    };
    "org/gnome/shell/extensions/user-theme" = {
      name = "Nordic";  # nordic should be installed
    };
    "org/gnome/desktop/wm/keybindings" = {
      # Actions
      cycle-windows = ["<Super>o"];
      close = ["<Alt>F4" "<Super>q"];
      # Workspace management
      switch-to-workspace-1 = ["<Super>1"];
      switch-to-workspace-2 = ["<Super>2"];
      switch-to-workspace-3 = ["<Super>3"];
      switch-to-workspace-4 = ["<Super>4"];
      switch-to-workspace-5 = ["<Super>5"];
      switch-to-workspace-6 = ["<Super>6"];
      switch-to-workspace-7 = ["<Super>7"];
      switch-to-workspace-8 = ["<Super>8"];
      switch-to-workspace-9 = ["<Super>9"];
      switch-to-workspace-10 = ["<Super>0"];
      switch-to-workspace-right = ["<Super>Right"];
      switch-to-workspace-left = ["<Super>Left"];
      move-to-workspace-1 = ["<Super><Shift>1"];
      move-to-workspace-2 = ["<Super><Shift>2"];
      move-to-workspace-3 = ["<Super><Shift>3"];
      move-to-workspace-4 = ["<Super><Shift>4"];
      move-to-workspace-5 = ["<Super><Shift>5"];
      move-to-workspace-6 = ["<Super><Shift>6"];
      move-to-workspace-7 = ["<Super><Shift>7"];
      move-to-workspace-8 = ["<Super><Shift>8"];
      move-to-workspace-9 = ["<Super><Shift>9"];
      move-to-workspace-10 = ["<Super><Shift>0"];
      move-to-monitor-left = ["<Super><Shift>["];
      move-to-monitor-right = ["<Super><Shift>]"];
      # Window sizes
      toggle-fullscreen = ["<Super>f"];
      toggle-maximize = ["<Super>m"];
      maximize = [];
      unmaximize = [];
      minimize = ["<Super><Shift>m"];
      # Other positions
      always-on-top = ["<Super><Shift>z"];
      toggle-on-all-workspaces = ["<Super><Shift>a"];
      # TODO: unbinding for now to free the ~/` in my keyboard
      switch-group = [];
      switch-group-backward = [];
    };
    "org/gnome/mutter/keybindings" = {
      toggle-tiled-left = ["<Super><Shift>h"];
      toggle-tiled-right = ["<Super><Shift>l"];
    };
    "org/gnome/shell/keybindings" = {
      switch-to-application-1 = [];
      switch-to-application-2 = [];
      switch-to-application-3 = [];
      switch-to-application-4 = [];
      switch-to-application-5 = [];
      switch-to-application-6 = [];
      switch-to-application-7 = [];
      switch-to-application-8 = [];
      switch-to-application-9 = [];
      focus-active-notification = ["<Super>."];
      toggle-message-tray = ["<Super>n"];
      toggle-overview = ["<Super>d"];
    };
    
    # Define arbitrary commands as custom key bindings
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gterminal/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/browser/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/editor/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot" = {
      name = "Screenshot (using Flameshot)";
      binding = "<Super><Shift>s";
      command = "${pkgs.flameshot}/bin/flameshot gui";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gterminal" = {
      name = "Terminal (new window)";
      binding = "<Super>t";
      command = "gnome-terminal";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/browser" = {
      name = "Web browser (Google Chrome)";
      binding = "<Super>b";
      command = "${pkgs.google-chrome}/bin/google-chrome-stable";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/editor" = {
      name = "Visual Studio Code";
      binding = "<Super>Return";
      command = "code";
    };
  };

  gtk = {
    enable = true;
    font.name = "Noto Sans";
    theme = {
      name = "Nordic";
      package = pkgs.nordic;
    };
  };

  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal.family = "JetBrainsMonoMedium Nerd Font";
        bold.family = "JetBrainsMonoMedium Nerd Font";
        italic.family = "JetBrainsMonoMedium Nerd Font";
        size = 12;
      };
      colors = {
        primary = {
          background = "#2e3440";
          foreground = "#d8dee9";
          dim_foreground = "#a5abb6";
        };
        cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        vi_mode_cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        selection = {
          # text = "CellForeground";
          background = "#4c566a";
        };
        search = {
          matches = {
            # foreground = "CellBackground";
            background = "#88c0d0";
          };
          bar = {
            background = "#434c5e";
            foreground = "#d8dee9";
          };
        };
        normal = {
          black = "#3b4252";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#88c0d0";
          white = "#e5e9f0";
        };
        bright = {
          black = "#4c566a";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#8fbcbb";
          white = "#eceff4";
        };
        dim = {
          black = "#373e4d";
          red = "#94545d";
          green = "#809575";
          yellow = "#b29e75";
          blue = "#68809a";
          magenta = "#8c738c";
          cyan = "#6d96a5";
          white = "#aeb3bb";
        };
      };
      key_bindings = [
        {
          key = "V";
          mods = "Control|Shift";
          action = "Paste";
        }
        {
          key = "C";
          mods = "Control|Shift";
          action = "Copy";
        }
      ];
      dynamic_padding = true;
    };
  };

  # Set the nord theme across the X server
  # home.file.".Xresources".source = ../assets/nord-xresources;
}
