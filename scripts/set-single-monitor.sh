#!/bin/sh

# xrandr | grep 'HDMI1 connected' &&
    xrandr --output $LAPTOP --primary --mode 1920x1080 --rotate normal \
           --output $HDMI --off \

pactl set-card-profile 0 output:analog-stereo

i3-msg restart
