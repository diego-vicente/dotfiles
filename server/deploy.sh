#!/usr/bin/env bash
#
# Push the dvicente-claw configs to the box.
#
#   server/deploy.sh
#
# Not part of link-dotfiles.sh on purpose: these files are only ever correct on
# claw, and symlinking them into a Mac's ~/.config would be actively wrong.

set -euo pipefail

readonly REMOTE_HOST="${CLAW_HOST:-dvicente@34.45.78.65}"
readonly REMOTE_KEY="${CLAW_KEY:-$HOME/.ssh/google_compute_engine}"
readonly SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly REMOTE_TMUX_DIR='~/.config/tmux'
readonly REMOTE_FISH_DIR='~/.config/fish'
readonly REMOTE_BIN_DIR='~/bin'

# Always force bash for remote commands. The login shell on claw may be fish,
# and every remote snippet below is bash syntax — `for ...; do ... done`,
# `$(...)`, `||` — which fish would reject outright.
ssh_claw()  { ssh -o ConnectTimeout=15 -i "$REMOTE_KEY" "$REMOTE_HOST" bash -c "$(printf '%q' "$*")"; }
ssh_script() { ssh -o ConnectTimeout=15 -i "$REMOTE_KEY" "$REMOTE_HOST" bash -s; }
scp_claw()  { scp -q -o ConnectTimeout=15 -i "$REMOTE_KEY" "$@"; }

echo "Deploying to ${REMOTE_HOST}..."

ssh_claw "mkdir -p ${REMOTE_TMUX_DIR} ${REMOTE_FISH_DIR}/functions ${REMOTE_BIN_DIR}"

scp_claw "${SRC_DIR}/tmux.conf"         "${REMOTE_HOST}:.config/tmux/tmux.conf"
scp_claw "${SRC_DIR}/fish/config.fish"  "${REMOTE_HOST}:.config/fish/config.fish"
scp_claw "${SRC_DIR}/bin/tmux-connect"  "${REMOTE_HOST}:bin/tmux-connect"
ssh_claw "chmod +x ${REMOTE_BIN_DIR}/tmux-connect"

echo "Verifying..."
ssh_script <<'REMOTE'
set -u
tmux -L deployverify -f ~/.config/tmux/tmux.conf start-server \; \
     source-file ~/.config/tmux/tmux.conf 2>&1 | head -5
tmux -L deployverify kill-server 2>/dev/null || true

fish -n ~/.config/fish/config.fish && echo "fish config OK"
sh -n ~/bin/tmux-connect && echo "tmux-connect OK"
tmux -L deployverify2 -f ~/.config/tmux/tmux.conf start-server 2>/dev/null
echo "default-shell: $(tmux -L deployverify2 show -gv default-shell 2>/dev/null)"
tmux -L deployverify2 kill-server 2>/dev/null || true
echo "$(tmux -V), $(fish --version)"
REMOTE

echo "Done."
