{ pkgs, nixosOptions, ... }:

{
  # Add the necessary networking utilities
  environment.systemPackages = with pkgs; [
    openvpn
    networkmanager-openvpn
    # TODO: find a way to add VPNs and drop this dependency
    gnome3.networkmanager-openvpn
  ];

  networking = {
    hostName = nixosOptions.networking.hostname;

    # Delegate networking to HostManager
    networkmanager.enable = true;

    # Set the firewall to allow ICMP traffic
    firewall = {
      enable = false;  # FIXME: allow ports from home-modules/chrome.nix
      allowPing = true;
      # allowedTCPPorts = [ ... ];
      # allowedUDPPorts = [ ... ];
    };

    # DHCP flag is soon to be deprecated, so it is set to false to emulate the
    # future default behavior. DHCP must be activated per interface.
    useDHCP = false;
    interfaces.${nixosOptions.networking.wireless}.useDHCP = true;

    # Disable IPv6 for now due to some router hiccups
    enableIPv6 = false;
  };

  # Enable the ClamAV service and keep the database up to date
  services.clamav = {
    daemon.enable = true;
    updater.enable = true;
  };
}
