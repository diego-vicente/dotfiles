#!/usr/bin/env bash
# Move Claude Code conversations and local state from one Mac to another.
#
#   claude-transfer.sh pack [archive]   on the old Mac
#   claude-transfer.sh unpack <archive> on the new Mac, after genesis.sh
#
# The archive holds a SHA-256 manifest of every file. unpack checks the archive
# against the manifest, copies the files in, and then checks every file again at
# its destination. The report lists each path as transferred or not.
#
# Credentials are not in the archive. macOS keeps the Claude Code login in the
# Keychain, so run `claude` and log in again on the new Mac.
set -euo pipefail

# Paths relative to $HOME. Conversations are in .claude/projects, in one folder
# per project whose name encodes the project's absolute path. They resume only
# if the username and the project paths stay the same on the new Mac.
readonly TRANSFER_ITEMS=(
  ".claude/projects"
  ".claude/plans"
  ".claude/file-history"
  ".claude/history.jsonl"
  ".claude/settings.local.json"
  ".claude/lib"
  ".claude/mcp-auth"
  ".claude.json"
)

readonly MANIFEST_NAME="MANIFEST.sha256"
readonly SOURCE_HOME_NAME="SOURCE_HOME"
readonly BACKUP_SUFFIX=".pre-transfer"
readonly DEFAULT_ARCHIVE="$HOME/Desktop/claude-transfer-$(date +%Y%m%d-%H%M).tar.gz"
# The archive holds the account state in .claude.json, so only the owner reads it
readonly ARCHIVE_MODE="600"

# Global, because the EXIT trap runs after the function that set it returns
WORKDIR=""
trap 'rm -rf "$WORKDIR"' EXIT

usage() {
  echo "usage: $(basename "$0") pack [archive] | unpack <archive>" >&2
  exit 2
}

main() {
  local command="${1:-}"
  case "$command" in
    pack) pack "${2:-$DEFAULT_ARCHIVE}" ;;
    unpack)
      [[ -n "${2:-}" ]] || usage
      unpack "$2"
      ;;
    *) usage ;;
  esac
}

pack() {
  local archive="$1"
  if pgrep -x claude >/dev/null; then
    echo "warning: Claude Code is running. A conversation that changes now is copied as it was." >&2
  fi

  WORKDIR="$(mktemp -d)"
  local payload="$WORKDIR/payload"
  mkdir -p "$payload"

  local item
  for item in "${TRANSFER_ITEMS[@]}"; do
    if [[ ! -e "$HOME/$item" ]]; then
      echo "skip     $item (not on this Mac)"
      continue
    fi
    mkdir -p "$payload/$(dirname "$item")"
    rsync -a "$HOME/$item" "$payload/$(dirname "$item")/"
    echo "packed   $item ($(du -sh "$payload/$item" | cut -f1))"
  done

  echo "$HOME" >"$payload/$SOURCE_HOME_NAME"
  (cd "$payload" && find . -type f ! -name "$MANIFEST_NAME" ! -name "$SOURCE_HOME_NAME" -print0 |
    xargs -0 shasum -a 256 >"$MANIFEST_NAME")

  tar -czf "$archive" -C "$payload" .
  chmod "$ARCHIVE_MODE" "$archive"
  echo
  echo "Archive: $archive ($(du -h "$archive" | cut -f1), $(wc -l <"$payload/$MANIFEST_NAME" | tr -d ' ') files)"
  echo "Move it to the new Mac, run '$(basename "$0") unpack <archive>', then delete it."
}

unpack() {
  local archive="$1"
  [[ -f "$archive" ]] || { echo "error: no archive at $archive" >&2; exit 1; }
  if pgrep -x claude >/dev/null; then
    echo "error: quit every Claude Code session first, because a running session overwrites these files." >&2
    exit 1
  fi

  WORKDIR="$(mktemp -d)"
  local workdir="$WORKDIR"
  tar -xzf "$archive" -C "$workdir"

  local manifest="$workdir/$MANIFEST_NAME"
  [[ -f "$manifest" ]] || { echo "error: the archive has no $MANIFEST_NAME" >&2; exit 1; }
  if ! (cd "$workdir" && shasum -a 256 --check --quiet "$MANIFEST_NAME"); then
    echo "error: the archive is damaged. Copy it again from the old Mac." >&2
    exit 1
  fi

  local source_home
  source_home="$(cat "$workdir/$SOURCE_HOME_NAME")"
  if [[ "$source_home" != "$HOME" ]]; then
    echo "warning: the old home was $source_home and this one is $HOME." >&2
    echo "         Conversations copy, but /resume cannot find them under the new paths." >&2
  fi

  local item
  for item in "${TRANSFER_ITEMS[@]}"; do
    [[ -e "$workdir/$item" ]] || continue
    copy_into_home "$workdir" "$item"
  done

  report "$manifest"
}

# Merge a folder into the existing one. Keep a backup of a file before replacing it.
copy_into_home() {
  local workdir="$1" item="$2"
  local destination="$HOME/$item"
  if [[ -d "$workdir/$item" ]]; then
    mkdir -p "$destination"
    rsync -a "$workdir/$item/" "$destination/"
    return
  fi
  mkdir -p "$(dirname "$destination")"
  if [[ -e "$destination" ]]; then
    cp "$destination" "$destination$BACKUP_SUFFIX"
  fi
  # cp writes through a symlink, so ~/.claude.json keeps its link into the repository
  cp "$workdir/$item" "$destination"
}

# Check every file of the manifest at its destination and print one line per item
report() {
  local manifest="$1"
  local results="$manifest.results"
  (cd "$HOME" && shasum -a 256 --check "$manifest" 2>/dev/null) >"$results" || true

  local item total verified status failures=0
  echo
  printf '%-10s %-32s %s\n' "STATUS" "PATH" "FILES VERIFIED"
  for item in "${TRANSFER_ITEMS[@]}"; do
    total="$(count_item_lines "$item" "$manifest")"
    if [[ "$total" -eq 0 ]]; then
      printf '%-10s %-32s %s\n' "ABSENT" "$item" "not in the archive"
      continue
    fi
    verified="$(grep ': OK$' "$results" | sed 's/: OK$//' | count_item_lines "$item")"
    status="OK"
    if [[ "$verified" -ne "$total" ]]; then
      status="FAILED"
      failures=$((failures + 1))
    fi
    printf '%-10s %-32s %s/%s\n' "$status" "$item" "$verified" "$total"
  done

  if [[ "$failures" -gt 0 ]]; then
    echo
    echo "Files that did not verify:"
    grep -v ': OK$' "$results" | sed 's/^/  /'
    exit 1
  fi
}

# Count the lines whose path is the item or lies inside it. A manifest line is
# "<64-character hash>  <path>", and a results line is only the path.
count_item_lines() {
  local item="$1" file="${2:-/dev/stdin}"
  awk -v item="./$item" '
    { path = ($0 ~ /^[0-9a-f]{64}  /) ? substr($0, 67) : $0 }
    path == item || index(path, item "/") == 1 { count++ }
    END { print count + 0 }
  ' "$file"
}

main "$@"
