#!/bin/sh
#
# Create a session from tmux's command prompt and switch to it.
#
#   prefix + N  ->  prompt pre-filled with "work/"  ->  type "api"  ->  work/api
#
# Takes one argument, the full session name. The context prefix decides the
# working directory, mirroring tmux-connect:
#
#   work/<project>      -> ~/Projects/<project>      (falls back to ~/Projects)
#   personal/<project>  -> ~/Projects/Personal/<...>  (falls back to that root)
#   <no prefix>         -> $HOME
#
# Kept separate from the fish function because tmux's run-shell uses /bin/sh and
# cannot call a fish function.

set -u

ROOT_WORK="$HOME/Projects"
ROOT_PERSONAL="$HOME/Projects/Personal"

name="${1:-}"
# Strip whitespace and any trailing slash left over from the pre-filled prompt.
name="$(printf '%s' "$name" | tr -d '[:space:]')"
name="${name%/}"

[ -n "$name" ] || exit 0

context="${name%%/*}"
project="${name#*/}"

case "$context" in
	work)     root="$ROOT_WORK" ;;
	personal) root="$ROOT_PERSONAL" ;;
	*)        root="$HOME"; project="" ;;
esac

workdir="$root"
if [ -n "$project" ] && [ "$project" != "$name" ] && [ -d "$root/$project" ]; then
	workdir="$root/$project"
fi

# -A so re-running with an existing name switches instead of erroring.
tmux new-session -A -d -s "$name" -c "$workdir"
tmux switch-client -t "$name"
