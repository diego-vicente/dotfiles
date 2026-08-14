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

sessions='#{E:@comp_sessions_sel}'
session_one='#{E:@comp_session_one}'
windows='#{E:@comp_windows_sel}'
right='#{E:@comp_right}#{E:@comp_ctx}'

# The modeline no longer gets a trailing space per tier: the pill's own closing
# fragment pads it, and doing both put two spaces before the right edge. The
# wide and medium tiers stay separate branches even though they now agree —
# dropping the path is modeline.sh's decision, made from the same width.
if [ "$width" -ge "$WIDTH_WIDE" ]; then
	left="$sessions"
	winlist="$windows"
elif [ "$width" -ge "$WIDTH_MEDIUM" ]; then
	left="$sessions"
	winlist="$windows"
elif [ "$width" -ge "$WIDTH_NARROW" ]; then
	left="$sessions"
	winlist=""
else
	left="$session_one"
	winlist=""
fi

tmux set -g status-left "$left" 2>/dev/null
tmux set -g status-right "$right" 2>/dev/null

# ---------------------------------------------------------------------------
# Wrap each group in its pill.
#
# The window pill is conditional IN THE FORMAT, not here: @comp_windows expands
# to nothing when the session has a single window, and that is decided at draw
# time, not at tier time. Wrapping it unconditionally would leave a pill
# containing one space — two caps and a gap — floating in the middle of the bar
# on every single-window session.
#
# The outer two use the flush variants so their edge cells keep the pill
# background for ghostty to extend into the padding. See status.conf.
# ---------------------------------------------------------------------------
open='#{E:@pill_open}';        close='#{E:@pill_close}'
open_flush='#{E:@pill_open_flush}'; close_flush='#{E:@pill_close_flush}'

# Flush on the screen-facing side only: the sessions pill is flush LEFT and
# capped right, the modeline pill is capped left and flush RIGHT.
#
# The modeline now ends with the workspace indicator rather than the orange
# allowance, so the colour ghostty extends into the right padding is the pill
# rather than the orange.
left_pill="$open_flush$left$close"
right_pill="$open$right$close_flush"
win_pill="#{?#{E:@comp_windows_sel},$open$winlist$close,}"
[ -z "$winlist" ] && win_pill=""

tmux set -g status-format[0] \
	"#[align=left]$left_pill#[align=centre]$win_pill#[align=right]$right_pill" 2>/dev/null

# One row. The half-block stretch experiment is gone: it cost a whole row of
# terminal to paint half of one, and the pills turned out to carry the
# separation on their own without spending any height at all.
tmux set -g status on 2>/dev/null
tmux set -gu status-format[1] 2>/dev/null

tmux refresh-client -S 2>/dev/null
