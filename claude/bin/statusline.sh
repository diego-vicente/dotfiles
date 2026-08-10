#!/bin/sh
#
# Claude Code status line — and the bridge that feeds tmux's modeline.
#
# Claude Code pipes a JSON blob in on stdin on every render. Two jobs:
#   1. print the line Claude Code shows at its own prompt
#   2. push the account-wide numbers into tmux options for the modeline
#
# The number that matters is rate_limits.five_hour.used_percentage — how much
# of the rolling 5-hour allowance is gone. That is deliberately NOT
# context_window.used_percentage, which is only this conversation's context and
# says nothing about how much headroom you have left before a wall.
#
# tmux options are set GLOBALLY: the 5h allowance is per account, not per
# session, so every session should show the same figure.

set -u

OPT_5H="@claude_5h"
OPT_7D="@claude_7d"
OPT_RESETS="@claude_5h_resets"
OPT_COST="@claude_cost"
OPT_MODEL="@claude_model"

json="$(cat)"

# jq is the only hard dependency here; degrade to a bare line without it.
if ! command -v jq >/dev/null 2>&1; then
	printf '%s' "$json" | sed -n 's/.*"display_name":"\([^"]*\)".*/\1/p'
	exit 0
fi

field() { printf '%s' "$json" | jq -r "$1 // empty" 2>/dev/null; }

model="$(field '.model.display_name')"
cwd="$(field '.workspace.current_dir')"
branch="$(field '.workspace.git_worktree')"
ctx_pct="$(field '.context_window.used_percentage')"
five_h="$(field '.rate_limits.five_hour.used_percentage')"
seven_d="$(field '.rate_limits.seven_day.used_percentage')"
resets="$(field '.rate_limits.five_hour.resets_at')"
cost="$(field '.cost.total_cost_usd')"

# Round the percentages; Claude sends floats like 23.5.
round() { [ -n "$1" ] && printf '%.0f' "$1" 2>/dev/null || printf ''; }
five_h_r="$(round "$five_h")"
seven_d_r="$(round "$seven_d")"

if command -v tmux >/dev/null 2>&1 && [ -n "${TMUX:-}" ]; then
	[ -n "$five_h_r"  ] && tmux set -g "$OPT_5H"   "$five_h_r"  2>/dev/null
	[ -n "$seven_d_r" ] && tmux set -g "$OPT_7D"   "$seven_d_r" 2>/dev/null
	[ -n "$cost"      ] && tmux set -g "$OPT_COST" "$(printf '%.2f' "$cost" 2>/dev/null)" 2>/dev/null
	[ -n "$model"     ] && tmux set -g "$OPT_MODEL" "$model" 2>/dev/null
	[ -n "$resets"    ] && tmux set -g "$OPT_RESETS" "$resets" 2>/dev/null
fi

# Claude Code's own status line stays EMPTY on purpose — the numbers live in
# the tmux bar instead. This script is configured as statusLine only because
# that is the only place Claude Code exposes rate_limits at all; hooks do not
# receive it.
#
# Tradeoff worth knowing: configuring any statusLine makes Claude Code drop
# most of its footer keyboard hints ("esc to interrupt", "? for shortcuts").
printf ''
