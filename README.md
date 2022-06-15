# `dotfiles` - Diego Vicente's config files

This repository contains my personal configuration. It is based on [Nix][1], [NixOS][2] and [`home-manager`][3] to allow for easier reproducibility and a more uniform configuration.

In the past, I tried several configurations based on complicated scripts and symlinking that were unrealiable or hard to correctly reproduce. I also enjoy my super-customized and personal environment, which was a pain to correctly set up for the first time in a new machine or installation. For that reason, I decided to climb the steep learning curve of Nix, and port the configuration to it.

This configuration currently manages the following machines:
- `korolev`, my personal home-built desktop PC.
- `vostok`, my personal laptop, a Dell XPS 15 9560.
- `soyuz`, my work laptop, a Dell XPS 15 9570.

It currently uses [flakes][4] to handle the different configurations, and as such all commands detailed below are expected to have a flakes-capable Nix version.

## Setting up the machine

I tend to perform a basic install using the default command to generate a configuration when installing. Before installing it, I like to disable any desktop manager - since my configuration does not use any, switching from one another may result in the system crashing. The only step needed when installing the system in a new machine is to write a new bootstrap file including the relevant hardware information.

If the machine is a new one that is expected to be completely managed by the repository, first link the hardware configuration to be tracked by the repository.

```shell
cd path/to/dotfiles
# If the machine is new and has not been saved to the repository
cat /etc/nixos/hardware-configuration.nix > ./hardware-configuration/$HOSTNAME.nix
```

Bear in mind that for some services to work, a GPG key must be present to decode its password. If the GPG key is present, you can safely set up the system.

If using a NixOS machine, you can run:

```shell
sudo nixos-rebuild switch --flake github:diego-vicente/dotfiles
```

This will look for current `$HOSTNAME` in the flakes repository. To choose a derivation explicitly, you can use `github:diego-vicente/dotfiles#korolev`, for example.

If on the other hand it is a non-NixOS machine, you can use `home-manager` to set the user configuration with:

```shell
home-manager switch --flake "github:diego-vicente/dotfiles"
```

Which will look for `$USERNAME@$HOSTNAME` by default, you can explicitly set the desired flake just like the example before.

## Storing secrets

The `passwords` directory contains a set of GPG files that can be decrypted with my private key in order to get the secrets. The files are easy to create and read:

```shell
# To encode a password - use a throwaway file, do not pipe in the password!
gpg --recipient mail@diego.codes --armor --encrypt passwords/service
# To get the password from a encrypted file
gpg --decrypt passwords/service.asc 2> /dev/null
```

[1]: https://nixos.wiki/wiki/Nix
[2]: https://nixos.org/
[3]: https://github.com/nix-community/home-manager
[4]: https://nixos.wiki/wiki/Flakes