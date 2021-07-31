{ config, lib, pkgs, ... }:

let
  v4l = pkgs.v4l-utils;
in {
  # Install video4linux utilites
  home.packages = [ v4l ];

  # Define a systemd service that sets the values when booting
  systemd.user.services.set-webcam = {
    Unit = {
      Description = "Set the correct settings for the webcam using V4L.";
      Documentation = [ "man:v4l2-ctl(1)" ];
    };

    Install.WantedBy = [ "graphical-session.target" ];

    Service = {
      ExecStart = ''
        ${v4l}/bin/v4l2-ctl \
          --set-ctrl=contrast=100 \
          --set-ctrl=saturation=140 \
          --set-ctrl=white_balance_temperature=2900 \
          --set-ctrl=sharpness=100
        '';
    };
  };
}
