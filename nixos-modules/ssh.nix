{ pkgs, ... }:

{
  # Enable the SSH agent.
  programs.ssh = {
    startAgent = true;
  };
}
