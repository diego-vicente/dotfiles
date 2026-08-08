#!/usr/bin/env bash
#
# Open (or focus) a Ghostty window permanently attached to one tmux workspace.
#
#   tmux-workspace.sh work
#   tmux-workspace.sh personal
#
# Idempotent: `new-session -A` attaches to an existing session and creates it
# only if missing, so re-running never forks a duplicate workspace.
#
# Why AppleScript and not `ghostty +new-window`: that subcommand is GTK/Linux
# only and Ghostty has said it will not come to the macOS CLI. Ghostty 1.3
# shipped a real AppleScript API instead, which is what this uses.
#
# Why the absolute tmux path: Ghostty runs `command` through a non-interactive
# login shell BEFORE ~/.zshrc is sourced, so a Homebrew PATH set there is not
# visible yet and a bare `tmux` fails with "command not found".

set -euo pipefail

readonly TMUX_BIN="/opt/homebrew/bin/tmux"
readonly WORKSPACE_WORK="work"
readonly WORKSPACE_PERSONAL="personal"

# Work repos live directly under ~/Projects; personal ones are nested one level
# deeper, so "work" deliberately starts one directory up from "personal".
readonly DIR_WORK="${HOME}/Projects"
readonly DIR_PERSONAL="${HOME}/Projects/Personal"

usage() {
	echo "usage: $(basename "$0") {${WORKSPACE_WORK}|${WORKSPACE_PERSONAL}}" >&2
	exit 64
}

[ $# -eq 1 ] || usage

workspace="$1"
case "$workspace" in
	"$WORKSPACE_WORK")     workdir="$DIR_WORK" ;;
	"$WORKSPACE_PERSONAL") workdir="$DIR_PERSONAL" ;;
	*) usage ;;
esac

[ -d "$workdir" ] || { echo "no such directory: $workdir" >&2; exit 66; }

# Create the session detached first, so it exists even if the GUI step fails
# and so a phone can attach to it without a Ghostty window ever being open.
"$TMUX_BIN" new-session -A -d -s "$workspace" -c "$workdir"

readonly ATTACH_CMD="${TMUX_BIN} new-session -A -s ${workspace}"

osascript <<APPLESCRIPT
tell application "Ghostty"
	activate
	set cfg to new surface configuration
	set command of cfg to "${ATTACH_CMD}"
	set initial working directory of cfg to "${workdir}"
	set environment variables of cfg to {"TMUX_WORKSPACE=${workspace}"}
	new window with configuration cfg
end tell
APPLESCRIPT
