#!/bin/sh

# xrandr | grep 'HDMI1 connected' &&
xrandr --output $LAPTOP --mode 1920x1080 --pos 2560x576 --rotate normal \
       --output $HDMI --primary --mode 2560x1440 --pos 0x0 --rotate normal --set "Broadcast RGB" "Full"

pactl set-card-profile 0 output:hdmi-stereo

i3-msg restart
