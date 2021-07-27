# `dotfiles` - Diego Vicente's config files

This repository contains my personal configuration. It is based on
[Nix][1], [NixOS][2] and [`home-manager`][3] to allow for easier
reproducibility and a more uniform configuration.

In the past, I tried several configurations based on complicated scripts
and symlinking that were unrealiable or hard to correctly reproduce. I
also enjoy my super-customized and personal environment, which was a
pain to correctly set up for the first time in a new machine or
installation. For that reason, I decided to climb the steep learning
curve of Nix, and port the configuration to it.

This configuration currently manages the following machines:
- `korolev`, my personal home-built desktop PC.
- `vostok`, my personal laptop, a Dell XPS 15 9560.
- `soyuz`, my work laptop, a Dell XPS 15 9570.

## Expected channels

For this configuration to properly work, there are several channels
expected to be present in the package manager. Make sure they exist in
the system using `sudo nix-channels --list` or add them using:

``` shell
sudo nix-channel --add https://nixos.org/channels/nixos-21.05 nixos
sudo nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs-unstable
sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-21.05.tar.gz home-manager
sudo nix-channel --update
```

## Setting up the machine

I tend to perform a basic install using the default command to generate
a configuration when installing. Before installing it, I like to disable
any desktop manager - since my configuration does not use any, switching
from one another may result in the system crashing. The only step needed
when installing the system in a new machine is to write a new bootstrap
file including the relevant hardware information.

Assuming that the GPG key is already present in the directory, setting
up the machine is as easy as running a rebuild:

```shell
cd path/to/dotfiles
# If the machine is new and has not been saved to the repository
cat /etc/nixos/hardware-configuration.nix > ./hardware-configuration/$HOSTNAME.nix
# Link the bootstrap file to the system
sudo rm /etc/nixos/configuration.nix
sudo ln -s ./boostrap/$HOSTNAME.nix /etc/nixos/configuration.nix
# Let Nix do the heavy lifting
sudo nixos-rebuild switch
```

On the other hand, if the system is different Unix and the user is
managed by `home-manager`:

``` shell
ln -s ./boostrap/$HOSTNAME.nix ~/.config/nixpks/home.nix
home-manager switch
```

## Storing secrets

The `passwords` directory contains a set of GPG files that can be
decrypted with my private key in order to get the secrets. The files are
easy to create and read:

```shell
# To encode a password - use a throwaway file, do not pipe in the password!
gpg --recipient mail@diego.codes --armor --encrypt passwords/service
# To get the password from a encrypted file
gpg --decrypt passwords/service.asc 2> /dev/null
```


[1]: https://nixos.wiki/wiki/Nix
[2]: https://nixos.org/
[3]: https://github.com/nix-community/home-manager
