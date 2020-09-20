{ config, lib, pkgs, unstable, ... }:

{
  home.packages = [
    # FIXME: unstable.vcv-rack
    unstable.orca-c
  ];
}
