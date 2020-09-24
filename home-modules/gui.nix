{ config, lib, pkgs, emacsPkg, ... }:

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
      config =
        let
          up = "k";
          down = "j";
          left = "h";
          right = "l";
          mod = "Mod4";
          ws1 = "1: ";
          ws2 = "2: ";
          ws3 = "3: ";
          ws4 = "4: ";
          ws5 = "5: ";
          ws6 = "6: ";
          ws7 = "7: ";
          ws8 = "8: ";
          ws9 = "9: ";
          ws0 = "10: ";
          emacs = emacsPkg;
          modes = {
            resize = {
              message = "Resize current window";
              definition = {
                "${left}" = "resize shrink width 10 px or 10 ppt";
                "${down}" = "resize grow height 10 px or 10 ppt";
                "${up}" = "resize shrink height 10 px or 10 ppt";
                "${right}" = "resize grow width 10 px or 10 ppt";
                "Left" = "resize shrink width 10 px or 10 ppt";
                "Down" = "resize grow height 10 px or 10 ppt";
                "Up" = "resize shrink height 10 px or 10 ppt";
                "Right" = "resize grow width 10 px or 10 ppt";
                "Return" = "mode default";
                "Escape" = "mode default";
                "${mod}+r" = "mode default";
              };
            };
            toggleGaps = {
              message = "Set gaps: off [1], comfortable [2], pretty [3]";
              definition = {
                "1" = "gaps inner current set 0; gaps outer current set 0";
                "2" = "gaps inner current set 15; gaps outer current set 5";
                "3" = "gaps inner current set 20; gaps outer current set 7";
                "Return" = "mode default";
                "Escape" = "mode default";
              };
            };
            toggleScreen = {
              message = "Screen layout: single [1], home [2], work [3]";
              definition = {
                "1" = "exec --no-startup-id ${../bin/set-single-monitor.sh}";
                "2" = "exec --no-startup-id ${../bin/set-home-monitor.sh}";
                "3" = "exec --no-startup-id ${../bin/set-work-monitor.sh}";
                "Return" = "mode default";
                "Escape" = "mode default";
              };
            };
            toggleAudio = {
              message = "Audio output: laptop [1], HDMI [2], headphones [3]";
              definition = {
                "1" = "exec --no-startup-id ${../bin/set-laptop-audio.sh}";
                "2" = "exec --no-startup-id ${../bin/set-home-audio.sh}";
                "3" = "exec --no-startup-id ${../bin/set-headphones-audio.sh}";
                "Return" = "mode default";
                "Escape" = "mode default";
              };
            };
          };
        in {
          modifier = mod;
          keybindings = {
            "${mod}+q" = "kill";
            "${mod}+d" = "exec ${pkgs.rofi}/bin/rofi -show drun";
            "${mod}+Return" = "exec ${emacs}/bin/emacsclient -c";
            "${mod}+${up}" = "focus up";
            "${mod}+${down}" = "focus down";
            "${mod}+${left}" = "focus left";
            "${mod}+${right}" = "focus right";
            "${mod}+Up" = "focus up";
            "${mod}+Down" = "focus down";
            "${mod}+Left" = "focus left";
            "${mod}+Right" = "focus right";
            "${mod}+Shift+${up}" = "move up";
            "${mod}+Shift+${down}" = "move down";
            "${mod}+Shift+${left}" = "move left";
            "${mod}+Shift+${right}" = "move right";
            "${mod}+Shift+Up" = "move up";
            "${mod}+Shift+Down" = "move down";
            "${mod}+Shift+Left" = "move left";
            "${mod}+Shift+Right" = "move right";
            "${mod}+i" = "split h";
            "${mod}+o" = "split v";
            "${mod}+f" = "fullscreen toggle";
            "${mod}+e" = "layout toggle split";
            "${mod}+w" = "layout tabbed";
            "${mod}+a" = "focus parent";
            "${mod}+s" = "focus child";
            "${mod}+minus" = "move scratchpad";
            "${mod}+equal" = "scratchpad show";
            "${mod}+Shift+space" = "floating toggle";
            "${mod}+space" = "focus mode_toggle";
            "${mod}+1" = "workspace ${ws1}";
            "${mod}+2" = "workspace ${ws2}";
            "${mod}+3" = "workspace ${ws3}";
            "${mod}+4" = "workspace ${ws4}";
            "${mod}+5" = "workspace ${ws5}";
            "${mod}+6" = "workspace ${ws6}";
            "${mod}+7" = "workspace ${ws7}";
            "${mod}+8" = "workspace ${ws8}";
            "${mod}+9" = "workspace ${ws9}";
            "${mod}+0" = "workspace ${ws0}";
            "${mod}+Shift+1" = "move container to workspace ${ws1}";
            "${mod}+Shift+2" = "move container to workspace ${ws2}";
            "${mod}+Shift+3" = "move container to workspace ${ws3}";
            "${mod}+Shift+4" = "move container to workspace ${ws4}";
            "${mod}+Shift+5" = "move container to workspace ${ws5}";
            "${mod}+Shift+6" = "move container to workspace ${ws6}";
            "${mod}+Shift+7" = "move container to workspace ${ws7}";
            "${mod}+Shift+8" = "move container to workspace ${ws8}";
            "${mod}+Shift+9" = "move container to workspace ${ws9}";
            "${mod}+Shift+0" = "move container to workspace ${ws0}";
            "${mod}+Shift+r" = "restart";
            "XF86MonBrightnessDown" = "exec ${pkgs.xorg.xbacklight}/bin/xbacklight -5";
            "XF86MonBrightnessUp" = "exec ${pkgs.xorg.xbacklight}/bin/xbacklight +5";
            "XF86AudioRaiseVolume" = "exec --no-startup-id ${pkgs.alsaUtils}/bin/amixer -q set Master 5%+";
            "XF86AudioLowerVolume" = "exec --no-startup-id ${pkgs.alsaUtils}/bin/amixer -q set Master 5%-";
            "XF86AudioMute" = "exec --no-startup-id ${pkgs.alsaUtils}/bin/amixer -q set Master +1 toggle";
            "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
            "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
            "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
            "${mod}+Shift+Print" = let
              takeScreenshot = "${pkgs.maim}/bin/maim -s --format=png /dev/stdout";
              saveToClipboard = "${pkgs.xclip}/bin/xclip -selection clipboard -t image/png -i";
            in "exec ${takeScreenshot} | ${saveToClipboard}";
            # TODO: include binding for lock-and-blur.sh
            "${mod}+t" = "exec --no-startup-id WINIT_X11_SCALE_FACTOR=1 ${pkgs.alacritty}/bin/alacritty";
            "${mod}+Shift+t" = "exec --no-startup-id ${emacsPkg}/bin/emacsclient -c -e '(vterm)'";
            # Mode binding
            "${mod}+r" = ''mode "${modes.resize.message}"'';
            "${mod}+Shift+g" = ''mode "${modes.toggleGaps.message}"'';
            "${mod}+Shift+s" = ''mode "${modes.toggleScreen.message}"'';
            "${mod}+Shift+a" = ''mode "${modes.toggleAudio.message}"'';
          };
          colors = {
            background = "2e3440";
            focused = {
              border = "#5e81ac";
              background = "#5e81ac";
              text = "#eceff4";
              indicator = "#81a1c1";
              childBorder = "#5e81ac";
            };
            focusedInactive = {
              border = "#4c566a";
              background = "#4c566a";
              text = "#eceff4";
              indicator = "#5c667a";
              childBorder = "#4c566a";
            };
            unfocused = {
              border = "#4c566a";
              background = "#4c566a";
              text = "#eceff4";
              indicator = "#5c667a";
              childBorder = "#4c566a";
            };
            urgent = {
              border = "#bf616a";
              background = "#bf616a";
              text = "#2e3440";
              indicator = "#d08770";
              childBorder = "#bf616a";
            };
            placeholder = {
              border = "#000000";
              background = "#0c0c0c";
              text = "#eceff4";
              indicator = "#000000";
              childBorder = "#0c0c0c";
            };
          };
          gaps = {
            inner = 20;
            outer = 7;
          };
          window.border = 4;
          modes = {
            ${modes.resize.message} = modes.resize.definition;
            ${modes.toggleGaps.message} = modes.toggleGaps.definition;
            ${modes.toggleScreen.message} = modes.toggleScreen.definition;
            ${modes.toggleAudio.message} = modes.toggleAudio.definition;
          };
          fonts = [ "Iosevka 10" ];
          bars = [];  # bars are handled by services.polybar
          terminal = "alacritty";
          startup = [
            { command = "systemctl --user restart polybar"; always = true; notification = false; }
            { command = "hsetroot -solid \"#404552\""; always = true; notification = false; }
          ];
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
