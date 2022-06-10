{
  buildCustomNixOSConfig = { hostname }: {
    ${hostname} = lib.nixosSystem
      {
        inherit system pkgs; # TODO: is pkgs needed?
        modules = [
          ./bootstrap/soyuz.nix
        ];
      };
  };
}
