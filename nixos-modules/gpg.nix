{ pkgs, options }:

{
  # Enable GnuPG. For now, it does not control the SSH identities.
  programs.gnupg.agent = {
    enable = true;
    # enableSSHSupport = true;
    pinentryFlavor = "gnome3";
  };
}
