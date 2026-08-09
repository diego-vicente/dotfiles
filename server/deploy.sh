#!/usr/bin/env bash
#
# Push the dvicente-claw configs to the box.
#
#   server/deploy.sh
#
# Not part of link-dotfiles.sh on purpose: these files are only ever correct on
# claw, and symlinking them into a Mac's ~/.config would be actively wrong.

set -euo pipefail

readonly REMOTE_HOST="${CLAW_HOST:-claw}"
readonly REMOTE_KEY="${CLAW_KEY:-$HOME/.ssh/google_compute_engine}"
readonly SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly REMOTE_TMUX_DIR='~/.config/tmux'
readonly REMOTE_FISH_DIR='~/.config/fish'

# /usr/local/bin, NOT ~/bin. An SSH "initial command" (what rootshell runs on
# connect) is a non-login shell, whose PATH is only
# /usr/local/bin:/usr/bin:/bin:/usr/games — ~/bin is added by ~/.profile, which
# non-login shells never read. Putting it in ~/bin makes the phone fail with
# "command not found", the shell exit, and the tab close on connect.
readonly REMOTE_BIN_DIR='/usr/local/bin'

# Always force bash for remote commands. The login shell on claw may be fish,
# and every remote snippet below is bash syntax — `for ...; do ... done`,
# `$(...)`, `||` — which fish would reject outright.
ssh_claw()  { ssh -o ConnectTimeout=15 -i "$REMOTE_KEY" "$REMOTE_HOST" bash -c "$(printf '%q' "$*")"; }
ssh_script() { ssh -o ConnectTimeout=15 -i "$REMOTE_KEY" "$REMOTE_HOST" bash -s; }
scp_claw()  { scp -q -o ConnectTimeout=15 -i "$REMOTE_KEY" "$@"; }

echo "Deploying to ${REMOTE_HOST}..."

ssh_claw "mkdir -p ${REMOTE_TMUX_DIR} ${REMOTE_FISH_DIR}/functions"

scp_claw "${SRC_DIR}/tmux.conf"         "${REMOTE_HOST}:.config/tmux/tmux.conf"
scp_claw "${SRC_DIR}/fish/config.fish"  "${REMOTE_HOST}:.config/fish/config.fish"

# Staged through /tmp because /usr/local/bin needs root.
scp_claw "${SRC_DIR}/bin/tmux-connect"  "${REMOTE_HOST}:/tmp/tmux-connect"
ssh_claw "sudo install -m 0755 /tmp/tmux-connect ${REMOTE_BIN_DIR}/tmux-connect && rm -f /tmp/tmux-connect"

# Remove any older ~/bin copy: it precedes /usr/local/bin on a login shell's
# PATH, so a stale one would silently shadow the real thing.
ssh_claw 'rm -f ~/bin/tmux-connect'

echo "Verifying..."
ssh_script <<'REMOTE'
set -u
tmux -L deployverify -f ~/.config/tmux/tmux.conf start-server \; \
     source-file ~/.config/tmux/tmux.conf 2>&1 | head -5
tmux -L deployverify kill-server 2>/dev/null || true

fish -n ~/.config/fish/config.fish && echo "fish config OK"
sh -n /usr/local/bin/tmux-connect && echo "tmux-connect OK"

# The check that actually matters: is it reachable the way the phone runs it,
# i.e. a non-login shell? This is the failure that closes the tab on connect.
env -i PATH=/usr/local/bin:/usr/bin:/bin sh -c 'command -v tmux-connect' \
    && echo "reachable from a non-login PATH" \
    || { echo "NOT reachable from a non-login PATH"; exit 1; }
tmux -L deployverify2 -f ~/.config/tmux/tmux.conf start-server 2>/dev/null
echo "default-shell: $(tmux -L deployverify2 show -gv default-shell 2>/dev/null)"
tmux -L deployverify2 kill-server 2>/dev/null || true
echo "$(tmux -V), $(fish --version)"
REMOTE

echo "Done."
