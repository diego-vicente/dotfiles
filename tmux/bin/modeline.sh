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
	pct=$(tmux show -gv "$OPT_PCT" 2>/dev/null)
	resets=$(tmux show -gv "$OPT_RESETS" 2>/dev/null)
	[ -n "$pct" ] || return 0

	out="${pct}%"
	case "$resets" in
		''|*[!0-9]*) printf '%s' "$out"; return 0 ;;
	esac

	now=$(date +%s)
	left=$((resets - now))
	if [ "$left" -le 0 ]; then
		printf '%s (resetting)' "$out"
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

f=$(five_hour)

if [ "$width" -lt "$WIDTH_DROP_PATH" ]; then
	printf '%s' "$f"
	exit 0
fi

p=$(short_path "$pane_path")
if [ -n "$f" ]; then
	printf '%s   %s' "$p" "$f"
else
	printf '%s' "$p"
fi
