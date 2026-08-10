#!/bin/sh
#
# Publish Claude Code's state into tmux, for the session bar and the picker.
#
# Wired to several hook events in settings.json; the event name arrives both as
# $1 and in the stdin JSON. Each event maps to one state:
#
#   SessionStart      -> idle
#   UserPromptSubmit  -> running
#   PermissionRequest -> asking     (Claude is blocked ON YOU)
#   Notification      -> asking
#   Stop              -> done
#   StopFailure       -> error
#   SessionEnd        -> (cleared)
#
# State is written on the PANE, then aggregated onto the SESSION, because a
# session may hold several agents and the bar has room for one verdict.
#
# CAVEAT: Claude Code does not export $TMUX_PANE — it is inherited from the
# shell that launched `claude`. That holds when you start it in a pane, and
# does NOT hold under Remote Control or a daemon, where this no-ops on purpose
# rather than guessing which pane to blame.

set -u

STATE_IDLE="idle"
STATE_RUNNING="running"
STATE_ASKING="asking"
STATE_DONE="done"
STATE_ERROR="error"

PANE_OPT="@agent_pane"    # deliberately NOT the same name as SESSION_OPT:
                          # tmux options inherit, so an unset pane option would
                          # resolve to the session's value and clearing would
                          # silently never take effect.
WINDOW_OPT="@agent_win"
SESSION_OPT="@agent"

event="${1:-}"
[ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

case "$event" in
	SessionStart)      state="$STATE_IDLE" ;;
	UserPromptSubmit)  state="$STATE_RUNNING" ;;
	PermissionRequest) state="$STATE_ASKING" ;;
	Notification)      state="$STATE_ASKING" ;;
	Stop)              state="$STATE_DONE" ;;
	StopFailure)       state="$STATE_ERROR" ;;
	SessionEnd)        state="" ;;
	*)                 exit 0 ;;
esac

if [ -z "$state" ]; then
	tmux set -p -t "$TMUX_PANE" -u "$PANE_OPT" 2>/dev/null
else
	tmux set -p -t "$TMUX_PANE" "$PANE_OPT" "$state" 2>/dev/null
fi

# ---- aggregate the window's panes -----------------------------------------
# A separate option name from the session's: tmux options inherit, so reusing
# @agent here would make every window show the session's verdict.
window="$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)"
if [ -n "$window" ]; then
	win_winner=""
	for s in $(tmux list-panes -t "$window" -F "#{$PANE_OPT}" 2>/dev/null); do
		case "$s" in
			"$STATE_ASKING")  win_winner="$STATE_ASKING"; break ;;
			"$STATE_ERROR")   [ "$win_winner" = "$STATE_ASKING" ] || win_winner="$STATE_ERROR" ;;
			"$STATE_DONE")    case "$win_winner" in "$STATE_ASKING"|"$STATE_ERROR") ;; *) win_winner="$STATE_DONE" ;; esac ;;
			"$STATE_RUNNING") [ -n "$win_winner" ] || win_winner="$STATE_RUNNING" ;;
		esac
	done
	if [ -z "$win_winner" ]; then
		tmux set -w -t "$window" -u "$WINDOW_OPT" 2>/dev/null
	else
		tmux set -w -t "$window" "$WINDOW_OPT" "$win_winner" 2>/dev/null
	fi
fi

# ---- aggregate the session's panes down to one state ----------------------
# Ordered by how much each state is blocking YOU: something waiting on your
# input outranks something that merely finished.
session="$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)" || exit 0
[ -n "$session" ] || exit 0

winner=""
for s in $(tmux list-panes -s -t "$session" -F "#{$PANE_OPT}" 2>/dev/null); do
	case "$s" in
		"$STATE_ASKING")  winner="$STATE_ASKING"; break ;;
		"$STATE_ERROR")   [ "$winner" = "$STATE_ASKING" ] || winner="$STATE_ERROR" ;;
		"$STATE_DONE")    case "$winner" in "$STATE_ASKING"|"$STATE_ERROR") ;; *) winner="$STATE_DONE" ;; esac ;;
		"$STATE_RUNNING") [ -n "$winner" ] || winner="$STATE_RUNNING" ;;
	esac
done

if [ -z "$winner" ]; then
	tmux set -t "$session" -u "$SESSION_OPT" 2>/dev/null
else
	tmux set -t "$session" "$SESSION_OPT" "$winner" 2>/dev/null
fi

# Repaint now instead of waiting for status-interval.
tmux refresh-client -S 2>/dev/null

exit 0
