#!/bin/sh
#
# Pick the status-bar tier for the current client width.
#
# Called from the client-resized hook and on client-attached. Doing this in a
# script rather than a nested tmux format keeps the conditionals readable and,
# more importantly, testable — you can run it by hand with a width.
#
#   tmux/bin/status-tier.sh 80
#
# Widths are measured, not guessed: four sessions plus three windows plus a
# full modeline needs ~130 columns.

set -u

WIDTH_WIDE=160     # everything
WIDTH_MEDIUM=120   # drop the path
WIDTH_NARROW=80    # drop the window list and cost
# below WIDTH_NARROW: attached session name and the 5h figure only

width="${1:-}"
if [ -z "$width" ]; then
	width="$(tmux display-message -p '#{client_width}' 2>/dev/null)"
fi
case "$width" in ''|*[!0-9]*) exit 0 ;; esac

sessions='#{E:@comp_sessions}'
session_one='#{E:@comp_session_one}'
windows='#{E:@comp_windows}'
five='#{E:@comp_5h}'
cost='#{E:@comp_cost}'
path='#{E:@comp_path}'
clock='#{E:@comp_clock}'

if [ "$width" -ge "$WIDTH_WIDE" ]; then
	left="$sessions"
	right="$path  $five  $cost  $clock "
	winlist="$windows"
elif [ "$width" -ge "$WIDTH_MEDIUM" ]; then
	left="$sessions"
	right="$five  $cost  $clock "
	winlist="$windows"
elif [ "$width" -ge "$WIDTH_NARROW" ]; then
	left="$sessions"
	right="$five  $clock "
	winlist=""
else
	left="$session_one"
	right="$five "
	winlist=""
fi

tmux set -g status-left "$left" 2>/dev/null
tmux set -g status-right "$right" 2>/dev/null
tmux set -g status-format[0] "#[align=left]$left#[align=centre]$winlist#[align=right]$right" 2>/dev/null
tmux refresh-client -S 2>/dev/null
