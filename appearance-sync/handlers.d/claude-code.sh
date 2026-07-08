#!/usr/bin/env bash
# Handler: Claude Code Catppuccin theme.
#
# Rewrites the single active theme file (~/.claude/themes/catppuccin.json) with
# the Mocha (dark) or Latte (light) palette. Claude Code's themes-dir file
# watcher reloads the new colors live in any running session.
#
# A single slug (custom:catppuccin) is used because Claude caches the active
# theme selection per session — changing settings.json.theme mid-session is a
# no-op until restart, but rewriting the cached file's *contents* repaints live.
#
# The source palettes live next to this handler, inside the appearance-sync
# package (../claude-code/), so the whole engine is self-contained in dotfiles.

set -euo pipefail

readonly APPEARANCE_LIGHT="light"

# This handler lives in <pkg>/handlers.d/; palettes live in <pkg>/claude-code/.
readonly HANDLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PALETTE_DIR="${HANDLER_DIR%/handlers.d}/claude-code"
readonly PALETTE_DARK="${PALETTE_DIR}/catppuccin-mocha.json"
readonly PALETTE_LIGHT="${PALETTE_DIR}/catppuccin-latte.json"

readonly SETTINGS_FILE="${HOME}/.claude/settings.json"
readonly ACTIVE_THEME_FILE="${HOME}/.claude/themes/catppuccin.json"
readonly ACTIVE_THEME_SLUG="custom:catppuccin"
readonly JQ_BIN="/opt/homebrew/bin/jq"

readonly appearance="${1:-${APPEARANCE:-}}"

if [[ "${appearance}" == "${APPEARANCE_LIGHT}" ]]; then
  source_palette="${PALETTE_LIGHT}"
else
  source_palette="${PALETTE_DARK}"
fi

if [[ ! -f "${source_palette}" ]]; then
  echo "claude-code: missing palette ${source_palette}" >&2
  exit 1
fi

# Ensure settings.json points at our active slug (idempotent — only writes if changed).
if [[ ! -f "${SETTINGS_FILE}" ]]; then
  mkdir -p "$(dirname "${SETTINGS_FILE}")"
  echo '{}' > "${SETTINGS_FILE}"
fi
current_theme="$("${JQ_BIN}" -r '.theme // ""' "${SETTINGS_FILE}")"
if [[ "${current_theme}" != "${ACTIVE_THEME_SLUG}" ]]; then
  tmp_settings="$(mktemp "${SETTINGS_FILE}.XXXXXX")"
  "${JQ_BIN}" --arg theme "${ACTIVE_THEME_SLUG}" '.theme = $theme' "${SETTINGS_FILE}" > "${tmp_settings}"
  mv "${tmp_settings}" "${SETTINGS_FILE}"
fi

# Skip the theme file write if its content is already what we want.
mkdir -p "$(dirname "${ACTIVE_THEME_FILE}")"
if [[ -f "${ACTIVE_THEME_FILE}" ]] && cmp -s "${source_palette}" "${ACTIVE_THEME_FILE}"; then
  exit 0
fi

# Atomically overwrite the active theme file. Claude's themes-dir watcher fires
# on the rename and reloads the palette in any running session.
tmp_theme="$(mktemp "${ACTIVE_THEME_FILE}.XXXXXX")"
trap 'rm -f "${tmp_theme}"' EXIT
cp "${source_palette}" "${tmp_theme}"
mv "${tmp_theme}" "${ACTIVE_THEME_FILE}"
trap - EXIT
