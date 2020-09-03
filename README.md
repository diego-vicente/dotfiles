# `dotfiles` - Diego Vicente's config files

This repository contains all the configuration files for the system's basic
functionalities. The main thought after these configurations is to be symlinked
in the places where the system is looking for them. The folders at root level
identify the hostname of the machine they are supposed to configure:

- `vostok`: my personal laptop (Dell XPS 15 9560), which runs Void Linux.
- `soyuz`: my work laptop (Dell XPS 15 9570), which runs Debian.

Although the configuration currently aims for unified usability and
look-and-feel, keeping both explicitly different allow me to easily diverge
some aspects from to another. The first step for the configuration in my
workflow is:

```shell
ln -s $HOME/utils/dotfiles/$HOSTNAME $HOME/dotfiles
```

That way, the folder `~/dotfiles` contains all the configuration files for that
specific machine, and I can easily access them when needed. This is absolutely
not necessary: you can symlink directly from the git repository to the
configuration locations.

Apart from the configurations, each folder includes a basic `README` where some
details from the machine and the setup are contained.

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
