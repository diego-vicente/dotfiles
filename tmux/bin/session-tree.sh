#!/bin/sh
#
# prefix + s — the session picker, scoped to the current context.
#
# Sessions are named <context>/<project>. This shows only sessions sharing the
# attached session's context, and falls back to showing ALL of them when that
# would be empty (you are in an unprefixed session, or the context has nothing
# else in it) — an empty picker is worse than an unfiltered one.
#
# A script rather than a bare `choose-tree -f`: the filter format is evaluated
# per session and cannot decide "matched nothing, show everything instead".
# That count has to happen before the picker opens.

set -u

FORMAT_OPT="@tree_format"

current="$(tmux display-message -p '#{client_session}' 2>/dev/null)"
context="${current%%/*}"

format="$(tmux show -gv "$FORMAT_OPT" 2>/dev/null)"
[ -n "$format" ] || format='#{session_name}'

# No prefix on the current session means no context to scope to.
if [ "$context" = "$current" ] || [ -z "$context" ]; then
	exec tmux choose-tree -Zs -O name -F "$format"
fi

matches="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -c "^${context}/" || true)"
case "$matches" in ''|*[!0-9]*) matches=0 ;; esac

if [ "$matches" -gt 0 ]; then
	exec tmux choose-tree -Zs -O name \
		-f "#{m:${context}/*,#{session_name}}" \
		-F "$format"
else
	exec tmux choose-tree -Zs -O name -F "$format"
fi
