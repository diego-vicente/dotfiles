#!/bin/sh

# xrandr | grep 'HDMI1 connected' &&

xrandr --output $LAPTOP --primary --mode 1920x1080 --pos 0x900 --rotate normal \
       --output $HDMI --mode 1440x900 --pos 216x0 --rotate normal

# --set "Broadcast RGB" "Limited 16:235"

pactl set-card-profile 0 output:analog-stereo

i3-msg restart
