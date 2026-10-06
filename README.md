# `dotfiles` - Diego Vicente's config files

This repository contains all the code to configure the tools to my exact liking. All of the modules collected here are expected to be moved to `$XDG_CONFIG_HOME` (or `~/.config` by default). It also contains a very simple script to set everything in place using soft-linking to the local copy of this repository, without polluting the repository with other configurations.

## Install

To set everything up, simply clone the repository and run the script to link all the configurations:

```shell
./bin/link-dotfiles.sh
```


## New Mac

`genesis/` sets up a new Mac from this repository. Clone over HTTPS, because
the new Mac has no SSH key yet, and run the script:

```shell
git clone https://github.com/diego-vicente/dotfiles.git ~/Projects/Personal/dotfiles
~/Projects/Personal/dotfiles/genesis/genesis.sh
```

- `genesis.sh` installs Homebrew and everything in `genesis/Brewfile`, plus the
  tools whose vendors recommend their own installers. Then it links the
  configuration and sets fish as the login shell. It is safe to run again.
- `macos-defaults.sh` applies the system preferences. It is a separate step.
- `claude-transfer.sh pack` on the old Mac and `claude-transfer.sh unpack` on
  the new one move the Claude Code conversations and check every file.
