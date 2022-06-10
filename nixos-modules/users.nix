{ pkgs, options }:

{
  # GOTCHA: This user configuration is designed to be mutable, therefore the
  # first step out of the box should be to run `sudo passwd $USER`.
  users.mutableUsers = true;

  # Setting this will make both bash and zsh valid shells, so that the users
  # that choose zsh are not treated as SystemAccounts. There is a chance that
  # you may need to edit /var/lib/AccountsService/users/<name> to fix it.
  environment.shells = with pkgs; [ bashInteractive zsh ];
  
  users.users.dvicente = {
    description = "Diego Vicente";
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "video" "audio" ];
    shell = pkgs.zsh;
  };
}
