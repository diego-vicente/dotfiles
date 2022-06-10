{ pkgs, options }:

let
  v4l = pkgs.v4l-utils;
  # if hostname == "soyuz" then  else "/dev/video0";
  device = options.device;
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
          --device=${device} \
          --set-ctrl=white_balance_temperature_auto=0 \
          --set-ctrl=contrast=85 \
          --set-ctrl=saturation=140 \
          --set-ctrl=white_balance_temperature=2850 \
          --set-ctrl=sharpness=100
        '';
    };
  };
}
