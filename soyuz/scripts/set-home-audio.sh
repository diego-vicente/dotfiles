#!/bin/sh

# TODO: store this values in environment variables?
pactl set-card-profile 0 output:hdmi-stereo-extra2+input:analog-stereo
pactl set-sink-port 20 analog-output-speaker
pactl set-source-port 13 analog-input-internal-mic
