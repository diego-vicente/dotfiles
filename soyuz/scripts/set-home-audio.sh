#!/bin/sh

# TODO: store this values in environment variables?
pactl set-card-profile 0 output:hdmi-stereo-extra2+input:analog-stereo
pactl set-sink-port alsa_output.pci-0000_00_1f.3.hdmi-stereo-extra2 hdmi-output-2
pactl set-source-port alsa_input.pci-0000_00_1f.3.analog-stereo analog-input-internal-mic
