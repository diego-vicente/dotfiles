#!/bin/sh
#
# Clear a "finished" or "error" marker once you have actually LOOKED at it.
#
#   usage: agent-ack.sh <pane-id>
#
# Run in the background from pane-focus-in. Sleeps for the dwell, then clears —
# but only if all of this still holds:
#
#   * the marker is still finished/error. BLOCKED IS NEVER CLEARED THIS WAY:
#     seeing a blocked agent does not unblock it, so clearing on attention
#     would be a lie. Only the agent can end that condition.
#   * the token is unchanged, so an older timer cannot clear a newer state
#   * the pane is still the active one, in the active window, of an attached
#     session
#   * the terminal itself still has OS focus. pane-focus-in alone stays true
#     while you read email in a browser, which is not attention.
#
# The dwell exists so tabbing past a pane does not count as having read it.

set -u

DWELL_SECONDS=5

PANE_ATTN="@agent_attn"
PANE_TOKEN="@agent_token"
CLIENT_FOCUS_OPT="@client_focused"

pane="${1:-}"
[ -n "$pane" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

attn="$(tmux display-message -p -t "$pane" "#{$PANE_ATTN}" 2>/dev/null)"
case "$attn" in
	finished|error) ;;
	*) exit 0 ;;
esac

token_before="$(tmux display-message -p -t "$pane" "#{$PANE_TOKEN}" 2>/dev/null)"

sleep "$DWELL_SECONDS"

# Pane may have gone while we slept.
tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1 || exit 0

token_after="$(tmux display-message -p -t "$pane" "#{$PANE_TOKEN}" 2>/dev/null)"
[ "$token_before" = "$token_after" ] || exit 0

still="$(tmux display-message -p -t "$pane" "#{$PANE_ATTN}" 2>/dev/null)"
case "$still" in
	finished|error) ;;
	*) exit 0 ;;
esac

focused="$(tmux display-message -p -t "$pane" \
	'#{&&:#{pane_active},#{&&:#{window_active},#{session_attached}}}' 2>/dev/null)"
[ "$focused" = "1" ] || exit 0

client_focused="$(tmux show -gv "$CLIENT_FOCUS_OPT" 2>/dev/null)"
[ "$client_focused" = "0" ] && exit 0

tmux set -p -t "$pane" -u "$PANE_ATTN" 2>/dev/null
exec "$HOME/.claude/bin/tmux-agent-rollup.sh" "$pane"
