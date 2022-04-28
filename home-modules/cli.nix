{ config, lib, pkgs, hostSpecific, ... }:

{
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
    bottom
    ranger
    bat
    exa
    procs
    dust
    hyperfine
    bandwhich
    niv
    lorri
    direnv
    nixos-option
  ];

  # Enable and configure the git user
  programs.git = with hostSpecific.info; {
    enable = true;
    userName = userName;
    userEmail = userEmail;
    extraConfig = {
      # Only fast-forward by default. That way, git will push only if there are
      # no issues; otherwise we need to use one of:
      #   $ git pull --rebase    # to rebase when pulling
      #   $ git pull --ff        # to create a merge commit
      pull.ff = "only";
    };
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
    defaultOptions = [
      "--height=40%"
      "--reverse"
      "--color=fg:#D8DEE9,bg:#2E3440,hl:#A3BE8C,fg+:#D8DEE9,bg+:#434C5E,hl+:#A3BE8C"
      "--color=pointer:#BF616A,info:#4C566A,spinner:#4C566A,header:#4C566A,prompt:#81A1C1,marker:#EBCB8B"
    ];
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
      nix_shell = {
        format = "via [$symbol]($style)";
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
