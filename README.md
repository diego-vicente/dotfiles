# `dotfiles` - Diego Vicente's config files

This repository contains all the code to configure the tools to my exact liking. All of the modules collected here are expected to be moved to `$XDG_CONFIG_HOME` (or `~/.config` by default). It also contains a very simple script to set everything in place using soft-linking to the local copy of this repository, without polluting the repository with other configurations.

## Install

To set everything up, simply clone the repository and run the script to link all the configurations:

```shell
./bin/link-dotfiles.sh
```

