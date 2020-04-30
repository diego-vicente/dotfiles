#!/bin/sh

# xrandr | grep 'HDMI1 connected' &&
    xrandr --output $LAPTOP --primary --mode 1920x1080 --rotate normal \
           --output $HDMI --off \

~/dotfiles/scripts/set-laptop-audio.sh

i3-msg restart
