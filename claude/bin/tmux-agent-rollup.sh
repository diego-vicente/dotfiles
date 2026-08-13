#!/bin/sh
#
# Roll pane-level agent state up onto the window and the session.
#
# Called from tmux-agent-state.sh after every hook, and from tmux hooks on
# pane-exited / pane-died so a pane that dies while blocked cannot leave a
# marker stuck forever. Aliveness is an axis of its own: marmonitor learned the
# same lesson and now excludes dead-but-blocked sessions from its status line.
#
#   usage: tmux-agent-rollup.sh [<pane-id>]
#
# With no argument it rolls up every session, which is what the cleanup hooks
# want since the pane they are reacting to is already gone.

set -u

PANE_ATTN="@agent_attn"
PANE_PHASE="@agent_phase"
WINDOW_OPT="@agent_win"
SESSION_OPT="@agent"

command -v tmux >/dev/null 2>&1 || exit 0

# Display priority. Deliberately NOT Paseo's ordering, which puts running above
# a finished-but-unseen turn: their bucket sorts a list and drives auto-focus,
# ours answers one question — does this need me? A finished turn does; a running
# one explicitly does not.
#
#   blocked > error > finished > working > idle > (nothing)
rank() {
	case "$1" in
		blocked)  echo 5 ;;
		error)    echo 4 ;;
		finished) echo 3 ;;
		working)  echo 2 ;;
		idle)     echo 1 ;;
		*)        echo 0 ;;
	esac
}

# A pane shows its attention if it has one, else what its phase is doing.
#
# AN EMPTY PHASE IS THE ONLY THING THAT MEANS "NO AGENT HERE". A plain shell
# must never read as an idle agent, which is Paseo's null-is-not-idle rule, and
# the phase option only exists in a pane once SessionStart has fired there. So
# an empty phase contributes nothing, and every other phase contributes
# something.
#
# Any phase that is neither empty nor `working` displays as `idle`: a chat is
# open, no turn is running, and nothing waits on you. That covers the phase left
# behind by an acknowledged finish, and equally the phase left by an
# acknowledged error, which is still a live session rather than an absence.
pane_display() {
	a="$(tmux display-message -p -t "$1" "#{$PANE_ATTN}" 2>/dev/null)"
	[ -n "$a" ] && { echo "$a"; return; }
	p="$(tmux display-message -p -t "$1" "#{$PANE_PHASE}" 2>/dev/null)"
	[ -z "$p" ] && { echo ""; return; }
	[ "$p" = "working" ] && { echo working; return; }
	echo idle
}

roll() {
	scope_flag="$1"; target="$2"; option="$3"; panes="$4"
	best=""; best_rank=0
	for p in $panes; do
		d="$(pane_display "$p")"
		r="$(rank "$d")"
		if [ "$r" -gt "$best_rank" ]; then best_rank="$r"; best="$d"; fi
	done
	if [ -n "$best" ]; then
		tmux set $scope_flag -t "$target" "$option" "$best" 2>/dev/null
	else
		tmux set $scope_flag -t "$target" -u "$option" 2>/dev/null
	fi
}

roll_window() {
	panes="$(tmux list-panes -t "$1" -F '#{pane_id}' 2>/dev/null)"
	roll "-w" "$1" "$WINDOW_OPT" "$panes"
}

roll_session() {
	panes="$(tmux list-panes -s -t "$1" -F '#{pane_id}' 2>/dev/null)"
	roll "" "$1" "$SESSION_OPT" "$panes"
}

if [ "$#" -ge 1 ] && [ -n "${1:-}" ]; then
	win="$(tmux display-message -p -t "$1" '#{window_id}' 2>/dev/null)"
	ses="$(tmux display-message -p -t "$1" '#{session_name}' 2>/dev/null)"
	[ -n "$win" ] && roll_window "$win"
	[ -n "$ses" ] && roll_session "$ses"
else
	for w in $(tmux list-windows -a -F '#{window_id}' 2>/dev/null); do roll_window "$w"; done
	for s in $(tmux list-sessions -F '#{session_name}' 2>/dev/null); do roll_session "$s"; done
fi

tmux refresh-client -S 2>/dev/null
exit 0
