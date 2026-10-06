#!/bin/sh
#
# Replay each pane's Claude conversation after a restore.
#
# Run from @resurrect-hook-post-restore-all, once the panes exist again.
#
# WHY NOT @resurrect-processes. Adding `claude` to that list would relaunch a
# FRESH agent with no conversation, which is worse than an empty shell because
# it looks restored. The id has to be replayed explicitly, and only for panes
# that had one.
#
# The command is TYPED AND RUN. Diego wants to land in a restored workspace with
# the conversations already back, not in one holding fourteen unpressed command
# lines. The cost is real and worth stating: a restore launches every recorded
# agent at once, which is fourteen processes and fourteen API connections on
# this machine today.
#
# Set @claude-restore-autorun to 0 to have the line typed and left for you.

set -u

MAP="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-claude/pane-sessions.tsv"

command -v tmux >/dev/null 2>&1 || exit 0
[ -f "$MAP" ] || exit 0

autorun="$(tmux show -gv @claude-restore-autorun 2>/dev/null)"
[ -n "$autorun" ] || autorun=1

# The shell in a restored pane is not always ready the instant the hook fires,
# and send-keys into a shell that has not drawn its prompt loses the line.
sleep 1

while IFS="$(printf '\t')" read -r addr sid dir; do
	[ -n "${addr:-}" ] && [ -n "${sid:-}" ] || continue

	# The pane must exist AND be a plain shell. Refusing to type into a pane
	# that already has something running is what keeps this idempotent: a second
	# restore, or a manual prefix + Ctrl-r, cannot stack commands on top of a
	# session that already came back.
	cmd="$(tmux display-message -p -t "$addr" '#{pane_current_command}' 2>/dev/null)" || continue
	[ -n "$cmd" ] || continue
	case "$cmd" in
		sh|bash|zsh|fish|dash|ksh) ;;
		*) continue ;;
	esac

	# CLEAR THE LINE FIRST. The guard above only proves the pane is a shell, and
	# it stays a shell because send-keys types without pressing Enter — so a
	# second restore, or a manual prefix + Ctrl-r, appended the command to the
	# one already sitting there. C-u discards the line, which makes a repeat
	# replace rather than accumulate.
	tmux send-keys -t "$addr" C-u 2>/dev/null

	if [ -n "${dir:-}" ]; then
		tmux send-keys -t "$addr" "cd '$dir' && claude --resume $sid" 2>/dev/null
	else
		tmux send-keys -t "$addr" "claude --resume $sid" 2>/dev/null
	fi
	[ "$autorun" = "1" ] && tmux send-keys -t "$addr" Enter 2>/dev/null
	: 
done < "$MAP"

exit 0
