{ config, lib, pkgs, hostSpecific, ... }:

let
  # manix is a package to query Nix options and packages from the command line
  manix = (
    let
      rev = "1272c45ac2b4f07c74702e8bd9417d3bbfcab56b"; # 0.6.1
      src = builtins.fetchTarball "https://github.com/mlvzk/manix/archive/${rev}.tar.gz";
    in
      import src {}
  );
  # comma is a tool to run commands that are not installed in your system
  comma = (
    let
      rev = "4a62ec17e20ce0e738a8e5126b4298a73903b468";
      src = builtins.fetchTarball "https://github.com/Shopify/comma/archive/${rev}.tar.gz";
    in
      import src {}
  );
in {
  # Install all the important CLI tools for everyday use. These are available
  # accross the entire system and are non-dependant on any other shell
  home.packages = with pkgs; [
    git
    vim
    wget
    curl
    ripgrep
    fzf
    zoxide
    ytop
    ranger
    bat
    exa
    procs
    dust
    hyperfine
    bandwhich
    manix
    niv
    lorri
    direnv
    comma
  ];

  # Enable and configure the git user
  programs.git = with hostSpecific.info; {
    enable = true;
    userName = userName;
    userEmail = userEmail;
  };

  # Define ZSH as the default shell and configure some basic options like the
  # history and plugins to use.
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    history.path = ".zsh_history";
    initExtra = ''
                eval "$(${pkgs.starship}/bin/starship init zsh)"
                eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
                '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
    };
  };

  # fzf enables fuzzy completion utilities for different shell shortcuts.
  programs.fzf = rec {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "rg --files --no-ignore --hidden --follow --glob '!.git/*'";
    defaultOptions = [ "--height 40%" "--reverse" ];
  };

  # Configure starship as the prompt for the shell and enable the basic ZSH
  # integration
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      git_status = {
        # FIXME: disabled due to poor performance in very large repos
        disabled = true;
      };
    };
  };

  # Lorri, direnv and niv are used to generate, activate and pin development
  # environments.
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  services.lorri.enable = true;
}
