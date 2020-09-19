{ config, lib, pkgs, ... }:

{
  # Install all GUI related packages
  home.packages = with pkgs; [
    # GUI and similar
    rofi
    hsetroot
    xorg.xbacklight
    xclip
    playerctl
    maim
    imagemagick
  ];

  # Define the X session to use i3 and the defined configuration in the
  # repository. This session is saved in a custom script that allows to invoke
  # it from a NixOS configuration or another xinit script.
  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3-gaps;
      # TODO: migrate all config to nix
      extraConfig = builtins.readFile ../assets/i3.conf;
      config = {
        bars = [];
        terminal = "alacritty";
      };
    };
  };

  # Polybar is configured to spawn to very similar bars, both in the integrated
  # laptop screen and in an HDMI monitor.
  services.polybar = {
    enable = true;
    package = with pkgs; polybar.override {
      i3Support = true;
      alsaSupport = true;
      pulseSupport = true;
    };
    # TODO: migrate the polybar configuration to nix
    config = ../assets/polybar.conf;
    script = ''
      PATH=$PATH:${pkgs.i3} polybar bar-laptop &
      PATH=$PATH:${pkgs.i3} polybar bar-hdmi &
    '';
  };

  # Rofi is the application launcher, the cornerstone of the whole configuration
  # to access the different apps.
  programs.rofi = {
    enable = true;
    theme = ../assets/nord.rasi;
    font = "Iosevka 11";
    extraConfig = ''rofi.display-drun: Open'';
  };

  # The notifications service is configured to use dunst. Most of the following
  # configuration is basically setting the corresponding colors.
  services.dunst = {
    enable = true;
    settings = {
      global = {
        follow = "mouse";
        geometry = "300x5-30+20";
        shrink = "no";
        transparency = 0;
        notification_height = 0;
        separator_height = 2;
        padding = 8;
        horizontal_padding = 8;
        frame_width = 3;
        frame_color = "#aaaaaa";
        separator_color = "frame";
        sort = "yes";
        idle_threshold = 120;
        font = "Iosevka 11";
        line_height = 0;
        markup = "full";
        format = "<b>%s</b>\n%b";
        alignment = "left";
        show_age_threshold = 60;
        word_wrap = true;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = "yes";
        icon_position = "off";
        sticky_history = "yes";
        history_length = 20;
      };
      urgency_low = {
        background = "#2e3440";
        foreground = "#eceff4";
        frame_color = "#8fbcbb";
        timeout = 10;
      };
      urgency_normal = {
        background = "#2e3440";
        foreground = "#eceff4";
        frame_color = "#8fbcbb";
        timeout = 10;
      };
      urgency_critical = {
        background = "#2e3440";
        foreground = "#eceff4";
        frame_color = "#bf616a";
        timeout = 0;
      };
    };
  };

  # Picom is a compositor that is mainly use to add subtle effects and prevent
  # screen tearing without any other display manager.
  services.picom = {
    enable = true;
    shadow = false;
    vSync = true;
    fade = true;
    fadeDelta = 5;
    fadeSteps = [ "0.1" "0.1" ];
  };

  # The basic unit for the i3 configuration is the terminal, for which I like
  # alacritty with a Nord colorscheme.
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal.family = "Iosevka";
        bold.family = "Iosevka";
        italic.family = "Iosevka";
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
    };
  };
}
