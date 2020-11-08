{ config, lib, pkgs, hostname, hostSpecific, ... }:

{
  networking = {
    hostName = hostname;

    # Delegate networking to HostManager
    networkmanager.enable = true;

    # Set the firewall to allow ICMP traffic
    firewall = {
      enable = true;
      allowPing = true;
      # allowedTCPPorts = [ ... ];
      # allowedUDPPorts = [ ... ];
    };

    # DHCP flag is soon to be deprecated, so it is set to false to emulate the
    # future default behavior. DHCP must be activated per interface.
    useDHCP = false;
    interfaces.${hostSpecific.network.wireless}.useDHCP = true;

    # Disable IPv6 for now due to some router hiccups
    enableIPv6 = false;
  };
}
