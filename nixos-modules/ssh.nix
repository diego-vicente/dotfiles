{ pkgs, options }:

{
  # Enable the SSH agent.
  programs.ssh = {
    startAgent = true;
  };
}
