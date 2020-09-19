{ config, lib, pkgs, ... }:

let
  manix = (
    let
      rev = "1272c45ac2b4f07c74702e8bd9417d3bbfcab56b"; # 0.6.1
      src = builtins.fetchTarball "https://github.com/mlvzk/manix/archive/${rev}.tar.gz";
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
    # FIXME: zoxide
    ytop
    ranger
    bat
    exa
    procs
    dust
    hyperfine
    bandwhich
    manix
  ];

  # Enable and configure the git user
  programs.git = {
    enable = true;
    userName = "Diego Vicente";
    userEmail = "mail@diego.codes";
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
                '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
    };
  };

  # Configure starship as the prompt for the shell and enable the basic ZSH
  # integration
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # settings = TODO
  };
}