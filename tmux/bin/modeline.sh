#!/bin/sh
#
# Right-hand side of the tmux status bar.
#
#   ~/Pr/carto-ags-foundation-model   10% (3h 55m left)
#
# Called as #(modeline.sh #{pane_current_path}) so it re-runs every
# status-interval. That is also why it must stay cheap: a couple of `ls` calls
# and one `date`, no network, no jq.
#
# The percentage is the rolling 5-hour allowance, published by
# ~/.claude/bin/statusline.sh. The countdown is derived here rather than there
# so it keeps ticking while Claude Code sits idle and stops rendering.

set -u

# Read from the cache file rather than tmux options: options die with the tmux
# server, so a fresh server showed a blank allowance until an agent happened to
# render. The file survives server restarts and Claude not running at all.
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-claude/usage"

OPT_PCT="@claude_5h"
OPT_RESETS="@claude_5h_resets"

# ---------------------------------------------------------------------------
# Path, shortened to the minimum UNIQUE prefix of each parent.
#
# ~/Projects/carto-ags-foundation-model -> ~/Pr/carto-ags-foundation-model
# "Pr" because ~ also holds Pictures and Public, so "P" alone is ambiguous.
# The final component is never shortened — it is the bit you actually read.
# ---------------------------------------------------------------------------
short_path() {
	path="$1"
	case "$path" in
		"$HOME") printf '~'; return ;;
		"$HOME"/*) rest="${path#"$HOME"/}"; out="~"; parent="$HOME" ;;
		*) rest="${path#/}"; out=""; parent="/" ;;   # not "" — ls "" errors
	esac

	# Everything except the last component gets shortened.
	last="${rest##*/}"
	middle="${rest%/*}"
	[ "$middle" = "$rest" ] && middle=""

	if [ -n "$middle" ]; then
		IFS='/'
		for comp in $middle; do
			unset IFS
			n=1
			while [ "$n" -lt "${#comp}" ]; do
				prefix=$(printf '%s' "$comp" | cut -c1-"$n")
				# How many siblings share this prefix?
				matches=$(ls -1 "$parent" 2>/dev/null | grep -c "^$prefix" 2>/dev/null)
				# grep -c prints nothing useful if the dir is unreadable; treat as unique.
				case "$matches" in ''|*[!0-9]*) matches=1 ;; esac
				[ "$matches" -le 1 ] && break
				n=$((n + 1))
			done
			out="$out/$(printf '%s' "$comp" | cut -c1-"$n")"
			parent="$parent/$comp"
			IFS='/'
		done
		unset IFS
	fi

	printf '%s/%s' "$out" "$last"
}

# ---------------------------------------------------------------------------
# 5h allowance: "10% (3h 55m left)"
# ---------------------------------------------------------------------------
five_hour() {
	pct=""
	resets=""
	if [ -r "$STATE_FILE" ]; then
		while IFS='=' read -r k v; do
			case "$k" in
				five_h) pct="$v" ;;
				resets) resets="$v" ;;
			esac
		done < "$STATE_FILE"
	fi
	# tmux options are a fallback for a server populated before the cache existed.
	[ -n "$pct" ]    || pct=$(tmux show -gv "$OPT_PCT" 2>/dev/null)
	[ -n "$resets" ] || resets=$(tmux show -gv "$OPT_RESETS" 2>/dev/null)
	[ -n "$pct" ] || return 0

	out="${pct}%"
	case "$resets" in
		''|*[!0-9]*) printf '%s' "$out"; return 0 ;;
	esac

	now=$(date +%s)
	left=$((resets - now))
	if [ "$left" -le 0 ]; then
		# The stored window has already rolled over, so the cached percentage
		# describes a period that is over. Showing it would be a confident lie;
		# the dash keeps the field's width without claiming a number.
		printf '5h —'
		return 0
	fi
	h=$((left / 3600))
	m=$(((left % 3600) / 60))
	# H:MM, and always with the hour even when it is 0, so the field keeps a
	# stable width and the bar does not reflow every hour.
	printf '%s (%d:%02d left)' "$out" "$h" "$m"
}

# Below this width the path is dropped and only the allowance is shown — on a
# phone the percentage is the only part worth the columns.
WIDTH_DROP_PATH=100

pane_path="${1:-$PWD}"
width="${2:-999}"
case "$width" in ''|*[!0-9]*) width=999 ;; esac

# ---------------------------------------------------------------------------
# The allowance gets its own ORANGE SEGMENT, divided from the path by a solid
# powerline slash. Orange because the figure is Claude's, and a reader should
# not have to remember which grey number means what.
#
# tmux re-scans #() output for #[...] directives, verified by rendering: a
# printf emitting "#[fg=colour1]B" comes back as ESC[31m around the B. So the
# styling belongs here rather than in a second #(), and the bar keeps forking
# once per status-interval instead of twice.
#
# Colours arrive as arguments rather than being read from tmux, because this
# script already runs inside a #() and shelling back out to `tmux show` for
# three values would triple its cost on every redraw.
# ---------------------------------------------------------------------------
pill="${3:-}"
orange="${4:-}"
canvas="${5:-}"
SEP_SOLID=$(printf '\356\202\274')   # U+E0BC ple-upper_left_triangle

f=$(five_hour)

# The slash keeps the powerline colouring — pill ink over an orange background —
# because the pill is the LIGHTER of the two. ple-upper_left_triangle is drawn
# seven units past the top and bottom of the cell so nerd-fonts can butt two
# segments together without a hairline seam, and only the ink overshoots. Pill
# grey fringing onto the canvas measures 1.37 and disappears; orange would be
# 1.93 and would show. See the separator note in status.conf.
segment() {
	if [ -n "$pill" ] && [ -n "$orange" ] && [ -n "$canvas" ]; then
		printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s,bold] %s ' \
			"$pill" "$orange" "$SEP_SOLID" "$canvas" "$orange" "$1"
	else
		printf '   %s' "$1"
	fi
}

if [ "$width" -lt "$WIDTH_DROP_PATH" ]; then
	[ -n "$f" ] && segment "$f"
	exit 0
fi

p=$(short_path "$pane_path")
if [ -n "$f" ]; then
	printf '%s ' "$p"
	segment "$f"
else
	printf '%s' "$p"
fi
