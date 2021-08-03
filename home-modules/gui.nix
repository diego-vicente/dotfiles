{ config, lib, pkgs, emacsPkg, hostSpecific, ... }:

# TODO: the conditional i3 modes generation is a bunch of spaghetti code that
# should be refactored ASAP.

let
  # audioSettings is a set of attributes with some scripts designed to change
  # the audio to some predefined setups (laptop, HDMI, headphones) using the
  # pactl sink and port interfaces. These names are host specific.
  audioSettings = let
    generateScript = name: setting:
      pkgs.writeShellScriptBin name ''
        pactl set-card-profile 0 output:${setting.output.profile}+input:${setting.input.profile}
        pactl set-sink-port alsa_output.pci-0000_00_1f.3.${setting.output.profile} ${setting.output.port}
        pactl set-source-port alsa_input.pci-0000_00_1f.3.${setting.input.profile} ${setting.input.port}
        i3-msg mode default
      '';
  in {
    main = generateScript "set-main-audio" hostSpecific.audio.main;
    headphones = generateScript "set-headphones-audio" hostSpecific.audio.headphones;
    aux = if isNull hostSpecific.audio.aux
          then pkgs.writeShellScriptBin "set-aux-audio" ""
          else generateScript "set-aux-audio" hostSpecific.audio.aux;
  };
  # videoSettings is a set of attribute containing some scripts designed to
  # change the video output of the system. Most of the output names and
  # arguments are host specific. It also depends on the audioSettings set to
  # change the audio accordingly
  videoSettings = with hostSpecific; {
    aux = let
      scriptBody = if isNull video.aux then ""
                   else ''
            xrandr --output ${video.aux.output} --primary ${video.aux.xrandrArgs} --pos 0x0 \
                   --output ${video.main.output} ${video.main.xrandrArgs} --pos 2560x576
            ${audioSettings.aux}/bin/set-aux-audio
            i3-msg restart
          '';
    in pkgs.writeShellScriptBin "set-aux-video" scriptBody;
    main = let
      # Whether or not any aux output has to be switched off
      auxOff = if isNull video.aux then ""
               else "xrandr --output ${video.aux.output} --off";
    in pkgs.writeShellScriptBin "set-main-video" ''
      xrandr --output ${video.main.output} --primary ${video.main.xrandrArgs}
      ${auxOff}
      ${audioSettings.main}/bin/set-main-audio
      i3-msg restart
    '';
  };
in {
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
  ]
  # Video and audio scripts
  ++ lib.attrValues videoSettings
  ++ lib.attrValues audioSettings;

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
            # If there is an auxiliar video output, define a script to change to it.
            toggleScreen = if isNull hostSpecific.video.aux then null else {
              message = let
                main = hostSpecific.video.main.name;
                aux = hostSpecific.video.aux.name;
              in "Screen layout: ${main} [1], ${aux} [2]";
              definition = {
                "1" = "exec --no-startup-id ${videoSettings.main}/bin/set-main-video";
                "2" = "exec --no-startup-id ${videoSettings.aux}/bin/set-aux-video";
                "Return" = "mode default";
                "Escape" = "mode default";
              };
            };
            # Define a script to toggle audio input and output.
            toggleAudio = {
              message = with hostSpecific; let
                main = audio.main.name;
                headphones = audio.headphones.name;
                aux = if isNull audio.aux then "" else audio.aux.name;
              in if isNull audio.aux
                 then "Audio output: ${main} [1], ${headphones} [2]"
                 else "Audio output: ${main} [1], ${headphones} [2], ${aux} [3]";
              definition = with hostSpecific.audio; let
                # aux toggle is an optional button and the syntax is clunky
                auxToggle = if isNull aux then {} else {
                  "3" = "exec --no-startup-id ${audioSettings.aux}/bin/set-aux-audio";
                };
              in {
                "1" = "exec --no-startup-id ${audioSettings.main}/bin/set-main-audio";
                "2" = "exec --no-startup-id ${audioSettings.headphones}/bin/set-headphones-audio";
                "Return" = "mode default";
                "Escape" = "mode default";
              } // auxToggle;
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
            "${mod}+Shift+bracketleft" = "move workspace to output up";
            "${mod}+Shift+bracketright" = "move workspace to output right";
            "${mod}+Shift+r" = "restart";
            "XF86MonBrightnessDown" = "exec ${pkgs.xorg.xbacklight}/bin/xbacklight -5";
            "XF86MonBrightnessUp" = "exec ${pkgs.xorg.xbacklight}/bin/xbacklight +5";
            "XF86AudioRaiseVolume" = "exec --no-startup-id ${pkgs.alsaUtils}/bin/amixer -q set Master 5%+";
            "XF86AudioLowerVolume" = "exec --no-startup-id ${pkgs.alsaUtils}/bin/amixer -q set Master 5%-";
            "XF86AudioMute" = "exec --no-startup-id ${pkgs.alsaUtils}/bin/amixer -q set Master +1 toggle";
            "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
            "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
            "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
            # Open the selected text or clipboard contents in a Chromium window
            "${mod}+c" = "exec ${../bin/open-in-chromium.sh} $(${pkgs.xclip}/bin/xclip -o)";
            "${mod}+Shift+c" = "exec ${../bin/open-in-chromium.sh} $(${pkgs.xclip}/bin/xclip -o -s clipboard)";
            # Take screenshot and save it to the clipboard
            "${mod}+Shift+s" = let
              takeScreenshot = "${pkgs.maim}/bin/maim -s --format=png /dev/stdout";
              saveToClipboard = "${pkgs.xclip}/bin/xclip -selection clipboard -t image/png -i";
            in "exec ${takeScreenshot} | ${saveToClipboard}";
            # TODO: include binding for lock-and-blur.sh
            "${mod}+t" = "exec --no-startup-id WINIT_X11_SCALE_FACTOR=1 ${pkgs.alacritty}/bin/alacritty";
            "${mod}+Shift+t" = "exec --no-startup-id ${emacsPkg}/bin/emacsclient -c -e '(vterm)'";
            # Mode binding
            "${mod}+r" = ''mode "${modes.resize.message}"'';
            "${mod}+Shift+g" = ''mode "${modes.toggleGaps.message}"'';
            "${mod}+Shift+a" = ''mode "${modes.toggleAudio.message}"'';
            "${mod}+Shift+x" = if isNull modes.toggleScreen then null
                               else ''mode "${modes.toggleScreen.message}"'';
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
          window = {
            border = 4;
            commands = [
              {
                # Make Microsoft Teams notifications floating
                criteria = { title = "Microsoft Teams Notification"; };
                command = "floating enable";
              }
              {
                # Make Firefox Picture-In-Picture floating in all workspaces
                criteria = { window_role = "Toplevel"; };
                command = "sticky enable";
              }
            ];
          };
          modes = let
            # Screen toggle is an optional mode and the syntax is clunky
            screenToggle = if isNull modes.toggleScreen then {} else {
              ${modes.toggleScreen.message} = modes.toggleScreen.definition;
            };
          in {
            ${modes.resize.message} = modes.resize.definition;
            ${modes.toggleGaps.message} = modes.toggleGaps.definition;
            ${modes.toggleAudio.message} = modes.toggleAudio.definition;
          } // screenToggle;
          fonts = {
            names = [ "JetBrains Mono" ];
            size = 10.0;
          };
          bars = [];  # bars are handled by services.polybar
          terminal = "alacritty";
          startup = [
            {
              # Set main workspace
              command = "i3-msg 'workspace ${ws1}'";
              always = false;
              notification = false; }
            {
              # Restart polybar service to ensure proper socket connection
              command = "systemctl --user restart polybar";
              always = true;
              notification = false; }
            {
              # Set background as a solid color
              command = "hsetroot -solid \"#404552\"";
              always = true;
              notification = false; }
            # {
            #   # Make a sensible default video output
            #   command = ''xrandr | grep "${hostSpecific.video.hdmi.output} connected" && set-home-video'';
            #   always = false;
            #   notification = false;
            # }
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
    config = let
      colors = {
        foreground-alt = "#d8dee9";
        foreground = "#eceff4";
        background-alt = "#4c566a";
        background = "#2e3440";
        green = "#a3be8c";
        red = "#bf616a";
        yellow = "#ebcb8b";
        blue = "#88c0d0";
        purple = "#b48ead";
        aqua = "#8fbcbb";
        orange = "#d08770";
      };
      bar = {
        width = "100%";
        height = 35;
        fixed-center = false;
        background = colors.background;
        foreground = colors.foreground;
        line-size = 3;
        line-color = colors.red;
        padding-left = 5;
        padding-right = 5;
        module-margin-left = 1;
        module-margin-right = 2;
        font-0 = "JetBrains Mono Medium:size=10;1";
        font-1 = "unifont:fontformat=truetype:size=8:antialias=false;0";
        font-2 = "Font Awesome 5 Free:style=Regular:pixelsize=10;1";
        font-3 = "Font Awesome 5 Free:style=Solid:pixelsize=10;1";
        font-4 = "Font Awesome 5 Brands:pixelsize=10;1";
        font-5 = "Wuncon Siji:size=10; 1";
        modules-left = [ "i3" ];
        modules-center = [];
        modules-right = [
          "pulseaudio"
          "memory"
          "cpu"
          "wlan"
          "eth"
          "battery"
          "temperature"
          "date"
          "powermenu"
        ];
        cursor-click = "pointer";
        cursor-scroll = "ns-resize";
      };
      # The bar in the aux output is condition and the syntax is clunky
      auxBar = if isNull hostSpecific.video.aux then {} else {
        "bar/bar-aux" = bar // { monitor = hostSpecific.video.aux.output; };
      };
    in {
      "bar/bar-main" = bar // { monitor = hostSpecific.video.main.output; };
      "module/i3" = {
        type = "internal/i3";
        format = "<label-state> <label-mode>";
        ws-icon-0 = "1: ;";
        ws-icon-1 = "2: ;";
        ws-icon-2 = "3: ;";
        ws-icon-3 = "4: ;";
        ws-icon-4 = "5: ;";
        ws-icon-5 = "6: ;";
        ws-icon-6 = "7: ;";
        ws-icon-7 = "8: ;";
        ws-icon-8 = "9: ;";
        ws-icon-9 = "10: ;";
        index-sort = true;
        wrapping-scroll = false;
        pin-workspaces = true;
        label-mode-padding = 2;
        label-mode-foreground = colors.background;
        label-mode-background = colors.blue;
        label-focused = "%index%: %icon%";
        label-focused-background = colors.background-alt;
        label-focused-underline = colors.blue;
        label-focused-padding = 2;
        label-unfocused = "%index%: %icon%";
        label-unfocused-padding = 2;
        label-visible = "%index%: %icon%";
        label-visible-background = colors.background-alt;
        label-visible-underline = colors.blue;
        label-visible-padding = 2;
        label-urgent = "%index%: %icon%";
        label-urgent-background = colors.red;
        label-urgent-padding = 2;
      };
      "module/cpu" = {
        type = "internal/cpu";
        interval = 2;
        format-prefix = " ";
        format-prefix-foreground = colors.foreground-alt;
        format-underline = colors.aqua;
        label = "%percentage:2%%";
      };
      "module/memory" = {
        type = "internal/memory";
        interval = 2;
        format-prefix = " ";
        format-prefix-foreground = colors.foreground-alt;
        format-underline = colors.purple;
        label = "%percentage_used%%";
      };
      "module/wlan" = {
        type = "internal/network";
        interface = hostSpecific.network.wireless;
        interval = 3;
        format-connected = "<ramp-signal> <label-connected>";
        format-connected-underline = colors.green;
        label-connected = "%essid%";
        format-disconnected = "";
        ramp-signal-0 = "";
        ramp-signal-1 = "";
        ramp-signal-2 = "";
        ramp-signal-3 = "";
        ramp-signal-4 = "";
        ramp-signal-0-foreground = colors.red;
        ramp-signal-1-foreground = colors.yellow;
        ramp-signal-2-foreground = colors.yellow;
        ramp-signal-3-foreground = colors.green;
        ramp-signal-4-foreground = colors.green;
      };
      "module/eth" = {
        type = "internal/network";
        interface = hostSpecific.network.ethernet;
        interval = 3;
        format-connected-underline = colors.green;
        format-connected-prefix = " ";
        format-connected-prefix-foreground = colors.foreground-alt;
        label-connected = "%local_ip%";
        format-disconnected = "";
        accumulate-stats = true;
      };
      "module/date" = {
        type = "internal/date";
        interval = 5;
        date = "";
        date-alt = " %Y-%m-%d";
        time = "%H:%M";
        time-alt = "%H:%M:%S";
        format-prefix = "";
        format-prefix-foreground = colors.foreground-alt;
        format-underline = colors.blue;
        label = "%date% %time%";
      };
      "module/pulseaudio" = {
        type = "internal/pulseaudio";
        format-volume = "<label-volume> <bar-volume>";
        label-volume = " %percentage%%";
        label-volume-foreground = colors.foreground;
        label-muted = " muted";
        label-muted-foreground = "#666";
        bar-volume-width = 10;
        bar-volume-foreground-0 = colors.green;
        bar-volume-foreground-1 = colors.green;
        bar-volume-foreground-2 = colors.green;
        bar-volume-foreground-3 = colors.green;
        bar-volume-foreground-4 = colors.green;
        bar-volume-foreground-5 = colors.orange;
        bar-volume-foreground-6 = colors.red;
        bar-volume-gradient = false;
        bar-volume-indicator = "|";
        bar-volume-indicator-font = 2;
        bar-volume-fill = "▊";
        bar-volume-fill-font = 2;
        bar-volume-empty = "─";
        bar-volume-empty-font = 2;
        bar-volume-empty-foreground = colors.foreground-alt;
      };
      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "AC";
        full-at = 98;
        format-charging = "<label-charging>";
        format-charging-foreground = colors.foreground-alt;
        format-charging-underline = colors.yellow;
        format-charging-prefix = " ";
        format-charging-prefix-foreground = colors.foreground-alt;
        format-discharging = "<ramp-capacity> <label-discharging>";
        format-discharging-underline = colors.yellow;
        format-full-prefix = " ";
        format-full-prefix-foreground = colors.foreground-alt;
        format-full-underline = colors.yellow;
        ramp-capacity-0 = "";
        ramp-capacity-1 = "";
        ramp-capacity-2 = "";
        ramp-capacity-3 = "";
        ramp-capacity-4 = "";
        ramp-capacity-foreground = colors.foreground-alt;
      };
      "module/temperature" = {
        type = "internal/temperature";
        thermal-zone = 0;
        hwmon-path = hostSpecific.temperature.package;
        warn-temperature = 80;
        format = "<ramp> <label>";
        format-underline = colors.red;
        format-warn = "<ramp> <label-warn>";
        format-warn-underline = colors.red;
        label = "%temperature-c%";
        label-warn = "%temperature-c%";
        label-warn-foreground = colors.red;
        ramp-0 = "";
        ramp-1 = "";
        ramp-2 = "";
        ramp-3 = "";
        ramp-4 = "";
        ramp-5 = "";
        ramp-6 = "";
        ramp-7 = "";
        ramp-foreground = colors.foreground-alt;
      };
      "module/powermenu" = {
        type = "custom/menu";
        expand-right = true;
        format-spacing = 1;
        label-open = "";
        label-open-foreground = colors.red;
        label-close = " cancel";
        label-close-foreground = colors.red;
        label-separator = "|";
        label-separator-foreground = colors.foreground-alt;
        menu-0-0 = "reboot";
        menu-0-0-exec = "menu-open-1";
        menu-0-1 = "power off";
        menu-0-1-exec = "menu-open-2";
        menu-0-2 = "suspend";
        menu-0-2-exec = "menu-open-3";
        menu-1-0 = "cancel";
        menu-1-0-exec = "menu-open-0";
        menu-1-1 = "reboot";
        menu-1-1-exec = "${pkgs.systemd}/bin/reboot";
        menu-2-0 = "power off";
        menu-2-0-exec = "${pkgs.systemd}/bin/poweroff";
        menu-2-1 = "cancel";
        menu-2-1-exec = "menu-open-0";
        menu-3-0 = "suspend";
        menu-3-0-exec = "${../bin/lock-and-blur.sh} && systemctl suspend";
        menu-3-1 = "cancel";
        menu-3-1-exec = "menu-open-0";
      };
      "settings" = {
        screenchange-reload = true;
      };
      "global/wm" = {
        margin-top = 5;
        margin-bottom = 5;
      };
    } // auxBar;
    script = ''
      PATH=$PATH:${pkgs.i3} polybar bar-main &
      PATH=$PATH:${pkgs.i3} polybar bar-aux &
    '';
  };

  # Rofi is the application launcher, the cornerstone of the whole configuration
  # to access the different apps.
  programs.rofi = {
    enable = true;
    theme = ../assets/nord.rasi;
    font = "JetBrains Mono Medium 11";
    extraConfig = {
      display-drun = "Open";
    };
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
        font = "JetBrains Mono Medium 10";
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
        normal.family = "JetBrains Mono Medium";
        bold.family = "JetBrains Mono Medium";
        italic.family = "JetBrains Mono Medium";
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
}
