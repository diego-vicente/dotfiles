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
    flameshot
    imagemagick
  ]
  # Video and audio scripts
  ++ lib.attrValues videoSettings
  ++ lib.attrValues audioSettings;

  # Define the X session to use i3 and the defined configuration in the
  # repository. This session is saved in a custom script that allows to invoke
  # it from a NixOS configuration or another xinit script.
  # xsession = {
  #   enable = true;
  #   scriptPath = ".hm-xsession";
  # };

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
      edge-tiling = true;
      workspaces-only-on-primary = true;
      attach-modal-dialogs = true;
    };
    "org/gnome/shell/extensions/user-theme" = {
      name = "Nordic";  # nordic should be installed
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

  # qt = {
  #   enable = true;
  #   platformTheme = "gnome";
  # };

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
