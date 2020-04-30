#!/bin/sh

# TODO: store this values in environment variables?
pactl set-card-profile 0 output:analog-stereo+input:analog-stereo
pactl set-sink-port 20 analog-output-headphones
pactl set-source-port 13 analog-input-headset-mic
