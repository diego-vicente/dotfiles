#!/usr/bin/env bash

# This script will create soft links to the git repository in the 
# needed XDG directories within the home directory.

run_id=$(date +'%y%m%d_%H%M')

link_or_replace () {
	origin=$1;
	target=$2;

	if [ "$(readlink $target)" = "$origin" ]; then
		echo "Link $target already exists, skipping...";
		return;

	elif [ -e $target ]; then
		echo "Backing up $target to ./backup/$run_id...";
		mkdir -p ./backup/$run_id;
		mv -r $target ./backup/$run_id/;

	fi;

	echo "Linking $origin -> $target...";
	ln -s $origin $target;
}

# Set everything in place
link_or_replace $PWD/nvim        $HOME/.config/nvim;
link_or_replace $PWD/wezterm     $HOME/.config/wezterm;
link_or_replace $PWD/fish	 $HOME/.config/fish;
link_or_replace $PWD/git                 $HOME/.config/git;
link_or_replace $PWD/git-hooks           $HOME/.git-hooks;
link_or_replace $PWD/karabiner           $HOME/.config/karabiner;
link_or_replace $PWD/zellij              $HOME/.config/zellij;
link_or_replace $PWD/atuin               $HOME/.config/atuin;
link_or_replace $PWD/btop                $HOME/.config/btop;
link_or_replace $PWD/helix               $HOME/.config/helix;
link_or_replace $PWD/cmux                $HOME/.config/cmux;
link_or_replace $PWD/claude              $HOME/.claude;
link_or_replace $PWD/claude/claude.json  $HOME/.claude.json;
link_or_replace $PWD/ghostty             $HOME/.config/ghostty;
link_or_replace $PWD/opencode            $HOME/.config/opencode;
link_or_replace $PWD/zsh/.zshenv         $HOME/.zshenv;
