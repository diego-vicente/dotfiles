#!/bin/sh
#
# Record which Claude conversation each pane holds, at SAVE time.
#
# Run from @resurrect-hook-post-save-all, so the addresses written here are the
# ones tmux-resurrect just wrote into its own save file. Recording them any
# earlier is unsafe: `renumber-windows on` shifts window indices whenever a
# window closes, so an address captured at SessionStart can be stale by now.
#
# The id itself comes from the @claude_session_id pane option, set by
# ~/.claude/bin/tmux-agent-state.sh on SessionStart. That option travels with
# the pane through any renumbering, which is why the two halves are split this
# way — the id is captured when it is knowable, the address when it is stable.

set -u

MAP="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-claude/pane-sessions.tsv"

command -v tmux >/dev/null 2>&1 || exit 0
mkdir -p "$(dirname "$MAP")" || exit 0

tmp="$MAP.$$"
: > "$tmp" || exit 0

# session:window.pane, conversation id, working directory. The cwd is recorded
# even though resurrect restores it, because `claude --resume` resolves its
# transcript from the directory it runs in — a resume in the wrong place finds
# nothing.
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}	#{@claude_session_id}	#{pane_current_path}' 2>/dev/null \
	| awk -F'\t' 'NF==3 && $2 != "" { print }' >> "$tmp"

mv -f "$tmp" "$MAP" 2>/dev/null || rm -f "$tmp"
exit 0
