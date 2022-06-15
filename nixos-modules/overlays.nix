[
  # This set of overlays is applied to the complete set of the Nix packages.
  # Every time an overlay should be applied to the bare NixOS configuration or
  # by a program not directly managed by home-manager (even if home-manager is
  # the one installing it), the overlay should be placed here.
  ( 
    self: super: {
      # Set the Chrome to dark mode always
      google-chrome = super.google-chrome.override {
        commandLineArgs = "--enable-features=WebUIDarkMode --force-dark-mode";
      };
      # TODO: come back to Nordic once GTK4 is supported?
      # nordic = super.nordic.overrideAttrs ( _: {
      #   srcs = [
      #     (super.fetchFromGitHub {
      #       owner = "EliverLara";
      #       repo = "Nordic";
      #       rev = "bbc9df3075f5422c120ddb943a0f0b376861033b";  # branch 42
      #       sha256 = "sha256-vTFzPm1aZ4HYNo75pqsUWbp432aaM3fHpSiUj7gIf78=";
      #       name = "Nordic";
      #     })
      #   ];
      # });
    }
  )
]


