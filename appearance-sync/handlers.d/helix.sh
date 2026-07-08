#!/usr/bin/env bash
# Handler: Helix theme.
#
# Rewrites the `theme = ` line in Helix's config.toml to the light or dark
# variant, then sends SIGUSR1 to every running `hx` process. Helix treats
# SIGUSR1 as "reload config", so open instances repaint live (buffers, cursor
# and undo history are preserved) — no restart needed.

set -euo pipefail

readonly APPEARANCE_LIGHT="light"
readonly HX_CONFIG="${HOME}/.config/helix/config.toml"
readonly HX_THEME_DARK="catppuccin_mocha"
readonly HX_THEME_LIGHT="catppuccin_latte"
readonly HX_BIN_NAME="hx"

readonly appearance="${1:-${APPEARANCE:-}}"

[[ -f "${HX_CONFIG}" ]] || exit 0

if [[ "${appearance}" == "${APPEARANCE_LIGHT}" ]]; then
  target_theme="${HX_THEME_LIGHT}"
else
  target_theme="${HX_THEME_DARK}"
fi

# Skip the rewrite + reload if the theme is already correct, to avoid a
# needless repaint on unrelated GlobalPreferences changes.
current_theme="$(sed -n -E 's/^theme = "([^"]+)".*/\1/p' "${HX_CONFIG}" | head -n1)"
if [[ "${current_theme}" == "${target_theme}" ]]; then
  exit 0
fi

# BSD sed (macOS) requires the empty-string argument to -i for in-place edits.
sed -i '' -E "s/^theme = .*/theme = \"${target_theme}\"/" "${HX_CONFIG}"

# pkill exits non-zero when no hx is running; that's fine.
pkill -USR1 "${HX_BIN_NAME}" 2>/dev/null || true
