#!/bin/sh
#
# Publish Claude Code's state into tmux, for the status bar and the picker.
#
# TWO AXES, kept separate on purpose. Every tool that got this right (Paseo,
# cmux, marmonitor) separates them; the ones that collapsed them into a single
# "unread badge" hit the same bugs.
#
#   PHASE      what the agent is doing. A pure function of the last hook.
#              (none) | working | blocked | idle | error
#
#   ATTENTION  whether it wants YOU. This is what the glyph shows.
#              blocked | finished | error | (none)
#
# The rule three unrelated codebases converge on:
#
#   FINISHED IS A NOTIFICATION. The work is done and safe; seeing it IS the
#   resolution. It clears on attention, or when the next turn starts.
#
#   BLOCKED IS A CONDITION. Seeing it does not resolve it — the agent is still
#   stuck. It clears ONLY when the condition ends: a tool proceeds, you deny, an
#   elicitation is answered, the turn stops, or the session ends.
#
# `finished` is raised on the working -> idle EDGE, not by Stop alone: a Stop
# after an idle stretch is not a completion.
#
# CAVEAT: Claude Code does not export $TMUX_PANE — it is inherited from the
# shell that launched `claude`. True when you start it in a pane, false under
# Remote Control or a daemon, where this no-ops rather than guessing.

set -u

PHASE_WORKING="working"
PHASE_BLOCKED="blocked"
PHASE_IDLE="idle"
PHASE_ERROR="error"

ATTN_BLOCKED="blocked"
ATTN_FINISHED="finished"
ATTN_ERROR="error"

# Distinct option names per scope. tmux options INHERIT, so a pane sharing a
# name with its session would resolve to the session's value and could never be
# cleared.
PANE_PHASE="@agent_phase"
PANE_ATTN="@agent_attn"
PANE_TOKEN="@agent_token"
PANE_SID="@claude_session_id"

event="${1:-}"
[ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

pane="$TMUX_PANE"
get()       { tmux display-message -p -t "$pane" "#{$1}" 2>/dev/null; }
set_opt()   { tmux set -p -t "$pane" "$1" "$2" 2>/dev/null; }
unset_opt() { tmux set -p -t "$pane" -u "$1" 2>/dev/null; }

prev_phase="$(get "$PANE_PHASE")"
prev_attn="$(get "$PANE_ATTN")"

phase="$prev_phase"
attn="$prev_attn"
clear_phase=0

case "$event" in
	SessionStart)
		# RECORD WHICH CONVERSATION THIS PANE HOLDS. Every hook receives
		# {session_id, transcript_path, cwd, ...} as JSON on stdin, and nothing
		# else exposes the id: claude appends to its transcript and closes it, so
		# no file handle is held, and `ps` shows the id only for a session that
		# was started with an explicit --resume <uuid>.
		#
		# ONLY on SessionStart. This script also runs on every PreToolUse and
		# PostToolUse, and reading stdin there would add a fork to the hottest
		# path in the config for a value that never changes.
		#
		# A PANE OPTION, not a file keyed by address. `renumber-windows on` means
		# window indices shift whenever a window closes, so any address recorded
		# now can be stale by the time a save runs. The option travels with the
		# pane; bin/resurrect-save-claude.sh reads it at save time, when the
		# addresses are the ones resurrect is actually writing down.
		if [ ! -t 0 ]; then
			sid=$(cat | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([0-9a-fA-F-]\{36\}\)".*/\1/p' | head -1)
			[ -n "$sid" ] && set_opt "$PANE_SID" "$sid"
		fi
		phase="$PHASE_IDLE"; attn="" ;;

	# --- work in progress --------------------------------------------------
	UserPromptSubmit)
		# A new turn supersedes anything you had not looked at yet.
		phase="$PHASE_WORKING"; attn="" ;;
	PreToolUse|PostToolBatch)
		phase="$PHASE_WORKING" ;;

	# --- the condition ended -----------------------------------------------
	# A tool actually proceeding is the signal that a human answered. Without
	# this transition, `blocked` persisted for the rest of the turn even though
	# nothing was waiting on you any more.
	PostToolUse|PostToolUseFailure|PermissionDenied|ElicitationResult)
		phase="$PHASE_WORKING"
		[ "$prev_attn" = "$ATTN_BLOCKED" ] && attn="" ;;

	# --- blocked on the human ----------------------------------------------
	PermissionRequest|Elicitation)
		phase="$PHASE_BLOCKED"; attn="$ATTN_BLOCKED" ;;
	Notification:permission_prompt|Notification:agent_needs_input|Notification:elicitation_dialog)
		phase="$PHASE_BLOCKED"; attn="$ATTN_BLOCKED" ;;

	# Claude nagging that it has been idle is NOT a block. Mapping the whole
	# Notification event to "asking" is what latched a permanent "?" that
	# nothing could clear.
	Notification:idle_prompt)
		phase="$PHASE_IDLE" ;;
	Notification:auth_success|Notification:elicitation_complete|Notification:elicitation_response)
		: ;;

	# --- turn ended ---------------------------------------------------------
	Stop|Notification:agent_completed)
		if [ "$prev_phase" = "$PHASE_WORKING" ] || [ "$prev_phase" = "$PHASE_BLOCKED" ]; then
			attn="$ATTN_FINISHED"
		elif [ "$prev_attn" = "$ATTN_BLOCKED" ]; then
			attn=""
		fi
		phase="$PHASE_IDLE" ;;
	StopFailure)
		phase="$PHASE_ERROR"; attn="$ATTN_ERROR" ;;

	# A subagent finishing says NOTHING about the parent turn. Explicit so it is
	# never helpfully "fixed" into a completion.
	SubagentStart|SubagentStop)
		: ;;

	SessionEnd)
		clear_phase=1; attn="" ;;

	*) exit 0 ;;
esac

if [ "$clear_phase" = 1 ] || [ -z "$phase" ]; then
	unset_opt "$PANE_PHASE"
else
	set_opt "$PANE_PHASE" "$phase"
fi

if [ -n "$attn" ]; then
	set_opt "$PANE_ATTN" "$attn"
	# A fresh token invalidates any dwell timer still sleeping for an older state.
	set_opt "$PANE_TOKEN" "$(date +%s)-$$"
else
	unset_opt "$PANE_ATTN"
fi

exec "$(dirname "$0")/tmux-agent-rollup.sh" "$pane"
