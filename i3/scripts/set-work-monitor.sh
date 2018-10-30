#!/bin/sh

# xrandr | grep 'HDMI1 connected' &&

xrandr --output eDP1 --primary --mode 1920x1080 --pos 0x392 --rotate normal \
       --output HDMI1 --mode 1440x900 --pos 1920x0 --rotate normal --set "Broadcast RGB" "Limited 16:235"


pactl set-card-profile 0 output:analog-stereo

i3-msg restart
