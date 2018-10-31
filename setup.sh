#!/bin/bash

if [ -z "$XDG_CONF_HOME" ]
then
    DEST=$HOME/.config
else
    DEST=$XDG_CONF_HOME
fi

ln -s $HOME/dotfiles/compton/config $DEST/compton.conf
ln -s $HOME/dotfiles/dunst/dunstrc  $DEST/dunst/dunstrc
ln -s $HOME/dotfiles/i3/config      $DEST/i3/config
ln -s $HOME/dotfiles/polybar/config $DEST/polybar/config

echo "Symbolic links in $DEST created"
