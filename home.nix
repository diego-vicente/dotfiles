{ config, lib, pkgs, ... }:

# The home-manager configuration for my user. There are still some things to
# work out:
# TODO: split the file in several smaller files
# TODO: generalize the declaration for work/personal machines
# TODO: move the i3 configuration here?
let neuron = (
    let neuronRev = "6f73e0b66ea78c343d0b0f856d176b74e25ce272"; # 0.6.6.2
        neuronSrc = builtins.fetchTarball "https://github.com/srid/neuron/archive/${neuronRev}.tar.gz";
     in import neuronSrc {});
in {
  # home.sessionVariables = {
  #   DOTFILES_DIR = "$HOME/etc/dotfiles";
  # };
  xdg.enable = true;

  # Allow unfree packages for the user
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    # GUI and basic configuration
    git
    rofi
    vim
    # Everyday packages and tools
    firefox
    spotify
    spotify-tui
    tdesktop  # telegram-desktop
    wget
    curl
    ripgrep
    # FIXME: zoxide
    ytop
    ranger
    bat
    exa
    procs
    dust
    hyperfine
    bandwhich
    # Mail utilities
    isync
    msmtp
    mu
    # neuron for note-taking
    neuron
  ];


  programs.mbsync.enable = true;
  # programs.msmtp.enable = true;
  # programs.notmuch = {
  #   enable = true;
  #   hooks = {
  #     preNew = "mbsync --all";
  #   };
  # };

  accounts.email.maildirBasePath = "docs/maildir";
  accounts.email.accounts.personal = {
    # Identity settings
    realName = "Diego Vicente";
    address = "mail@diego.codes";
    gpg = {
      key = "05655462B962E44888EAA98627A4876C982E4518";
      signByDefault = true;
    };
    # Configure the server connection details
    primary = true;
    userName = "mail@diego.codes";
    passwordCommand = "${pkgs.gnupg}/bin/gpg --decrypt ~/etc/dotfiles/passwords/mail.asc 2> /dev/null";
    imap = {
      host = "imap.migadu.com";
      port = 993;
    };
    smtp = {
      host = "smtp.migadu.com";
      port = 465;
    };
    # Enable the different services to take care of the mail
    mbsync = {
      enable = true;
      create = "maildir";
    };
    msmtp.enable = true;
    # notmuch.enable = true;
    # getmail.enable = true;
    # imapnotify.enable = true;
  };

  systemd.user = {
    # Define a new service to fetch the mail using systemd
    services = {
      mbsync = {
        Unit = {
          Description = "Mailbox syncronization";
          Documentation = [ "man:mbsync(1)" ];
        };
        Service = {
          Type = "oneshot";
          # TODO: declare relative to accounts.email.maildirBasePath
          ExecStart = "${pkgs.isync}/bin/mbsync -a && ${pkgs.mu}/bin/mu --maildir=~/docs/maildir/";
        };
        Install = {
          Path = [ "${pkgs.gnupg}/bin" ];
          After = [ "network-online.target" "gpg-agent.service" ];
          WantedBy = [ "default.target" ];
        };
      };
    };
    # Invoke the service once every 2 minutes
    timers = {
      mbsync = {
        Unit = {
          Description = "Periodical mailbox syncronization";
          Documentation = [ "man:mailbox(1)" ];
        };
        Timer = {
          OnCalendar = "*:0/2";
          Persistent = true;
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    history.path = ".zsh_history";
    initExtra = ''
                eval "$(${pkgs.starship}/bin/starship init zsh)"
                '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # settings = TODO
  };

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

  # Emacs configuration
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [
      epkgs.emacs-libvterm
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

  systemd.user.services.neuron = let
    zettelDir = "/home/dvicente/docs/neuron/zettelkasten";
  in {
    Unit.Description = "Neuron zettelkasten service";
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${neuron}/bin/neuron -d ${zettelDir} rib -wS";
    };
  };

  # Set up other configuration files
  xdg.configFile = {
    "i3/config".source = ./vostok/i3/config;
  };

  home.file = {
    ".Xresources".source = ./vostok/X/Xresources;
  };
}
