{ config, lib, pkgs, ... }:

let
  neuron = (
    let
      rev = "6f73e0b66ea78c343d0b0f856d176b74e25ce272"; # 0.6.6.2
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
}
