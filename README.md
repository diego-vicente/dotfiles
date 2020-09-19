# `dotfiles` - Diego Vicente's config files

This repository contains my personal configuration. It is based on [Nix][1],
[NixOS][2] and [`home-manager`][3] to allow for easier reproducibility and a
more uniform configuration.

In the past, I tried several configurations based on complicated scripts and
symlinking that were unrealiable or hard to correctly reproduce. I also enjoy my
super-customized and personal environment, which was a pain to correctly set up
for the first time in a new machine or installation. For that reason, I decided
to climb the steep learning curve of Nix, and port the configuration to it.


## Setting up the machine

**Note:** It is still on my to-do list to generalize this configuration to
multiple machines. Currently, it only supports `vostok`, my daily driver.

Assuming that the GPG key is already present in the directory, setting up the
machine is as easy as running a rebuild:

```shell
cd path/to/dotfiles
# If the machine is new and has not been saved to the repository
cat /etc/nixos/hardware-configuration.nix > ./hardware-configuration/$HOSTNAME.nix
# Link the bootstrap file to the system
sudo rm /etc/nixos/configuration.nix
sudo ln -s ./configuration.nix /etc/nixos/configuration.nix
# Let nixos-rebuild do the rest
sudo nixos-rebuild switch
```


## Storing secrets

The `passwords` directory contains a set of GPG files that can be decrypted with
my private key in order to get the secrets. The files are easy to create and
read:

```shell
# To encode a password - use a throwaway file, do not pipe in the password!
gpg --recipient mail@diego.codes --armor --encrypt passwords/service
# To get the password from a encrypted file
gpg --decrypt passwords/service.asc 2> /dev/null
```


[1]: https://nixos.wiki/wiki/Nix
[2]: https://nixos.org/
[3]: https://github.com/nix-community/home-manager
