#!/usr/bin/env bash
# Handler: lazygit theme.
#
# lazygit has NO live config reload — it reads its config only at startup and
# offers no reload signal. So this handler writes the chosen Catppuccin variant
# into lazygit's default config file (~/.config/lazygit/config.yml, since
# XDG_CONFIG_HOME is set); the new theme takes effect on the next lazygit launch.
#
# The variant files are theme-only fragments (gui.theme + authorColors); lazygit
# merges them over its built-in defaults, so they work as a standalone config.
# Sources live next to this handler, inside the appearance-sync package.

set -euo pipefail

readonly APPEARANCE_LIGHT="light"

# This handler lives in <pkg>/handlers.d/; variants live in <pkg>/lazygit/.
readonly HANDLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VARIANT_DIR="${HANDLER_DIR%/handlers.d}/lazygit"
readonly VARIANT_DARK="${VARIANT_DIR}/mocha.yml"
readonly VARIANT_LIGHT="${VARIANT_DIR}/latte.yml"

readonly LAZYGIT_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/lazygit/config.yml"

readonly appearance="${1:-${APPEARANCE:-}}"

if [[ "${appearance}" == "${APPEARANCE_LIGHT}" ]]; then
  source_variant="${VARIANT_LIGHT}"
else
  source_variant="${VARIANT_DARK}"
fi

if [[ ! -f "${source_variant}" ]]; then
  echo "lazygit: missing variant ${source_variant}" >&2
  exit 1
fi

# Skip the write if the live config already matches the target variant.
mkdir -p "$(dirname "${LAZYGIT_CONFIG}")"
if [[ -f "${LAZYGIT_CONFIG}" ]] && cmp -s "${source_variant}" "${LAZYGIT_CONFIG}"; then
  exit 0
fi

# Atomically overwrite so a lazygit launching mid-write never sees a partial file.
tmp_config="$(mktemp "${LAZYGIT_CONFIG}.XXXXXX")"
trap 'rm -f "${tmp_config}"' EXIT
cp "${source_variant}" "${tmp_config}"
mv "${tmp_config}" "${LAZYGIT_CONFIG}"
trap - EXIT
