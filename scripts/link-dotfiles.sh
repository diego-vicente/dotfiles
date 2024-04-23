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

