#!/bin/sh

# TODO: store this values in environment variables?
pactl set-card-profile 0 output:analog-stereo+input:analog-stereo
pactl set-sink-port alsa_output.pci-0000_00_1f.3.analog-stereo analog-output-speaker
pactl set-source-port alsa_input.pci-0000_00_1f.3.analog-stereo analog-input-internal-mic
