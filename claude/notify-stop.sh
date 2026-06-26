#!/bin/bash

# Notification hook for Stop event using Ghostty native notifications (OSC 777)

# Read the JSON input from stdin
INPUT=$(cat)

# Get session title
SESSION_TITLE=$(echo "$INPUT" | ~/.claude/get-session-title.sh)

# Sound configuration
SOUND="/System/Library/Sounds/Tink.aiff"

# Send Ghostty native notification via OSC 777
printf '\033]777;notify;%s;%s\007' "$SESSION_TITLE" "Claude Code Finished"

# Play sound
afplay "$SOUND" &
