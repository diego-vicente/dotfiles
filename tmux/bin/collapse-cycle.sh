#!/bin/sh
#
# Cycle which status-bar pill is collapsed, for the session the client is on.
#
#   (both expanded) -> sessions collapsed -> windows collapsed -> (both expanded)
#
# The mouse can only ever REACH a collapsed state, because the maximize marker
# exists only while something is collapsed. So the keyboard has to be the way
# back to both-expanded, and a cycle is the smallest binding that reaches all
# three.
#
# @collapse is session-scoped, so this writes to the client's current session
# rather than the global option. See the collapse note in status.conf for why
# the session is the right owner.

set -u

OPT="@collapse"

command -v tmux >/dev/null 2>&1 || exit 0

session="$(tmux display-message -p '#{client_session}' 2>/dev/null)"
[ -n "$session" ] || exit 0

case "$(tmux show -t "$session" -v "$OPT" 2>/dev/null)" in
	sessions) next=windows ;;
	windows)  next="" ;;
	*)        next=sessions ;;
esac

if [ -n "$next" ]; then
	tmux set -t "$session" "$OPT" "$next"
else
	tmux set -t "$session" -u "$OPT"
fi

tmux refresh-client -S 2>/dev/null
exit 0
