#!/usr/bin/env bash
# Appearance sync dispatcher.
#
# Detects the current macOS light/dark appearance once, then runs every
# executable handler in handlers.d/ — each handler is responsible for one app
# (Claude Code, Helix, ...). Adding a new app means dropping a script in
# handlers.d/; nothing here needs to change.
#
# Each handler receives the appearance ("dark"|"light") as $1 and via the
# exported $APPEARANCE env var. A handler that fails is logged and skipped so
# one broken app can't block the rest.
#
# Triggered by the launchd agent com.dvicente.appearance-sync, which watches
# ~/Library/Preferences/.GlobalPreferences.plist (rewritten on every toggle).

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HANDLERS_DIR="${SCRIPT_DIR}/handlers.d"
readonly APPEARANCE_DARK="dark"
readonly APPEARANCE_LIGHT="light"

# macOS: `defaults read -g AppleInterfaceStyle` prints "Dark" in dark mode and
# exits non-zero in light mode (the key is absent).
if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
  appearance="${APPEARANCE_DARK}"
else
  appearance="${APPEARANCE_LIGHT}"
fi
export APPEARANCE="${appearance}"

if [[ ! -d "${HANDLERS_DIR}" ]]; then
  echo "appearance-sync: no handlers dir at ${HANDLERS_DIR}" >&2
  exit 0
fi

for handler in "${HANDLERS_DIR}"/*; do
  [[ -f "${handler}" && -x "${handler}" ]] || continue
  handler_name="$(basename "${handler}")"
  if "${handler}" "${appearance}"; then
    echo "appearance-sync: ${handler_name} -> ${appearance}"
  else
    echo "appearance-sync: ${handler_name} FAILED (exit $?)" >&2
  fi
done
