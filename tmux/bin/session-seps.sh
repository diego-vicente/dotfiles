#!/bin/sh
#
# Publish each session's NEIGHBOURS, so the bar can draw one separator per
# boundary.
#
#   @sess_prev  name of the session before this one, empty for the first
#   @sess_next  name of the session after this one, empty for the last
#
# WHY THIS EXISTS
#
# Every boundary between two sessions must carry exactly ONE separator, and its
# shape depends on both sides: thin between two unselected sessions, solid where
# the chip opens, solid where the chip closes. #{S:} iterates one session at a
# time and cannot see the previous iteration, so an entry drawing its own left
# separator has no way to know a chip just closed beside it.
#
# WHY NEIGHBOURS AND NOT "THE SESSION AFTER THE SELECTED ONE"
#
# The first version published exactly that, computed from #{client_session}.
# It broke with two ghostty windows open on the same context: the script walked
# every attached client, wrote a value per client onto the same shared options,
# and the last write won. Switching one window to another session left the
# other window's answer in place, and the closing solid landed on the wrong
# entry.
#
# A neighbour is a property of the SESSION LIST alone. It does not mention a
# client, so it cannot disagree between two of them. The format then asks the
# per-client question itself, by comparing @sess_prev against #{client_session}
# at draw time. That comparison is evaluated once per client, which is exactly
# where the client-specific part belongs.
#
# It also means this script no longer runs on client-session-changed. Switching
# session cannot alter who neighbours whom.

set -u

OPT_PREV="@sess_prev"
OPT_NEXT="@sess_next"

command -v tmux >/dev/null 2>&1 || exit 0

# THE ORDER COMES FROM #{S:} ITSELF, never from list-sessions. The two disagree:
# list-sessions sorts by name, #{S:} walks the sessions in creation order.
# Reading the sorted list named the wrong neighbour, so the closing solid landed
# one entry early. The loop order is a property of the server, so any session
# works as the target.
anchor="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1)"
[ -n "$anchor" ] || exit 0

all="$(tmux display-message -p -t "$anchor" '#{S:#{session_name}
}' 2>/dev/null | grep -v '^$')"
[ -n "$all" ] || exit 0

# One list per context, because that is what the bar shows: @sess_filtered keeps
# only the sessions sharing the client's prefix. A session's neighbour inside
# its own context never depends on which client is looking.
contexts="$(printf '%s\n' "$all" | sed 's|/.*||' | sort -u)"

printf '%s\n' "$contexts" | while read -r ctx; do
	[ -n "$ctx" ] || continue
	names="$(printf '%s\n' "$all" | grep "^$ctx\(/\|$\)")"
	[ -n "$names" ] || continue

	# THE FIELD SEPARATOR MUST NOT BE WHITESPACE. A tab collapses here: the
	# shell treats runs of IFS whitespace as one delimiter and strips leading
	# ones, so the empty `prev` of the first entry disappeared and `next` slid
	# into its place. Every context's first session came out with its two
	# neighbours swapped. A non-whitespace IFS character delimits exactly one
	# field each time, empty or not.
	printf '%s\n' "$names" | awk '
		{ line[NR] = $0 }
		END {
			for (i = 1; i <= NR; i++)
				print line[i] "|" (i > 1 ? line[i-1] : "") "|" (i < NR ? line[i+1] : "")
		}
	' | while IFS='|' read -r name prev next; do
		[ -n "$name" ] || continue
		if [ -n "$prev" ]; then
			tmux set -t "$name" "$OPT_PREV" "$prev" 2>/dev/null
		else
			tmux set -t "$name" -u "$OPT_PREV" 2>/dev/null
		fi
		if [ -n "$next" ]; then
			tmux set -t "$name" "$OPT_NEXT" "$next" 2>/dev/null
		else
			tmux set -t "$name" -u "$OPT_NEXT" 2>/dev/null
		fi
	done
done

tmux refresh-client -S 2>/dev/null
exit 0
