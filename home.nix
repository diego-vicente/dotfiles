{ config, lib, pkgs, ... }:

# The home-manager configuration for my user. There are still some things to
# work out:
# TODO: split the file in several smaller files
# TODO: generalize the declaration for work/personal machines
# TODO: move the i3 configuration here?
{
  home.sessionVariables = {
    DOTFILES_DIR = "$HOME/etc/dotfiles";
  };
  xdg.enable = true;

  # Allow unfree packages for the user
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    # GUI and basic configuration
    git
    rofi
    rxvt-unicode
    vim
    # Everyday packages and tools
    firefox
    spotify
    spotify-tui
    tdesktop  # telegram-desktop
    wget
    curl
    ripgrep
    ytop
    ranger
    bat
    exa
    procs
    dust
    hyperfine
    bandwhich
  ];

  programs.bash.enable = true;

  # TODO: investigate the configuration possibilities
  programs.firefox = {
    enable = true;
  };

  services.spotifyd = {
    enable = true;
    settings = {
      global = {
        username = "diegovicente";
        # TODO: check if the pkg explicit call and output redirection are needed
        password_cmd = "${pkgs.gnupg}/bin/gpg --decrypt ~/etc/dotfiles/passwords/spotify.asc 2> /dev/null";
        bitrate = "320";
        device_name = "Spotifyd@vostok";
      };
    };
  };

  # Enable and configure the git user
  programs.git = {
    enable = true;
    userName = "Diego Vicente";
    userEmail = "mail@diego.codes";
  };

  # TODO: configure accounts.email

  # Emacs configuration
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [ epkgs.emacs-libvterm ];
  };

  services.emacs = {
    enable = true;
  };

  home.file.".doom.d" = {
    source = /home/dvicente/etc/dvm-emacs;
    recursive = true;
    onChange = builtins.readFile /home/dvicente/etc/dvm-emacs/bin/reload;
  };

  # Configure notification using dunst
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
        background = "#282828";
        foreground = "#fdf4c1";
        frame_color = "#fdf4c1";
        timeout = 10;
      };
      urgency_normal = {
        background = "#282828";
        foreground = "#fdf4c1";
        frame_color = "#fabd2f";
        timeout = 10;
      };
      urgency_critical = {
        background = "#282828";
        foreground = "#fdf4c1";
        frame_color = "#fb4934";
        timeout = 0;
      };
    };
  };

  # Configure rofi as the main launcher
  programs.rofi = {
    enable = true;
    theme = ./vostok/rofi/nord.rasi;
    font = "Iosevka 11";
    extraConfig = ''rofi.display-drun: Open'';
  };

  # Use Picom as compositor (mainly to prevent screen tearing)
  services.picom = {
    enable = true;
    shadow = false;
    vSync = true;
    fade = true;
    fadeDelta = 5;
    fadeSteps = [ "0.1" "0.1" ];
  };

  # Use polybar in i3
  services.polybar = {
    enable = true;
    package = with pkgs; polybar.override {
      i3Support = true;
      alsaSupport = true;
      pulseSupport = true;
    };
    config = ./vostok/polybar/config;
    script = ''
      PATH=$PATH:${pkgs.i3} polybar bar-laptop &
      PATH=$PATH:${pkgs.i3} polybar bar-hdmi &
    '';
  };

  # Set up other configuration files
  xdg.configFile = {
    "i3/config".source = ./vostok/i3/config;
  };

  home.file = {
    ".Xresources".source = ./vostok/X/Xresources;
  };
}
