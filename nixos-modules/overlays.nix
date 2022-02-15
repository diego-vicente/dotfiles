[
  # This set of overlays is applied to the complete set of the Nix packages.
  # Every time an overlay should be applied to the bare NixOS configuration or
  # by a program not directly managed by home-manager (even if home-manager is
  # the one installing it), the overlay should be placed here.
  ( 
    self: super: {
      # Set the Chrome to dark mode always
      google-chrome = super.google-chrome.override {
        commandLineArgs = "--force-dark-mode";
      };
      # Change the PaperWM version to next-release for Gnome 40 
      gnomeExtensions = super.gnomeExtensions // {
        paperwm = super.gnomeExtensions.paperwm.overrideAttrs ( _: {
          src = super.fetchFromGitHub {
            owner = "paperwm";
            repo = "PaperWM";
            rev = "e9f714846b9eac8bdd5b33c3d33f1a9d2fbdecd4"; # next-release
            sha256 = "0wdigmlw4nlm9i4vr24kvhpdbgc6381j6y9nrwgy82mygkcx55l1";
          };
        });
      };
    }
  )
]


