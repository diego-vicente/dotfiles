{ config, lib, pkgs, ... }:

let
  neuron = (
    let
      rev = "595f040293d746fc7e036cc872b7e48c1f45c7f1"; # 1.0.1.0
      src = builtins.fetchTarball "https://github.com/srid/neuron/archive/${rev}.tar.gz";
    in
      import src {}
  );
in {
  # Neuron allows to take linked notes (zettelkasten). Is based on plaintext
  # files and this service boots up a webserver allowing to read the notes on
  # the browser.
  systemd.user.services.neuron = let
    zettelDir = "/home/dvicente/docs/neuron/zettelkasten";
  in {
    Unit.Description = "Neuron zettelkasten service";
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${neuron}/bin/neuron -d ${zettelDir} rib -wS";
    };
  };

  home.packages = [ neuron ];
}
