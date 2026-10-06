#!/usr/bin/env bash
#
# Weekly maintenance for developer caches that grow without bound.
#
# Every action here is safe by design: each cache rebuilds itself on demand,
# and nothing outside the named paths is touched. Preview with DRY_RUN=1, or
# let com.dvicente.cache-cleanup.plist run it weekly.

set -uo pipefail

readonly DRY_RUN="${DRY_RUN:-0}"
readonly DATA_VOLUME="/System/Volumes/Data"
readonly PROJECTS_DIR="$HOME/Projects"
readonly DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
readonly SESSION_LOG_DIR="$HOME/.claude/projects"
readonly SPOTLIGHT_MARKER=".metadata_never_index"

# Age thresholds, in days.
readonly DERIVED_DATA_MAX_AGE=30
readonly SESSION_LOG_MAX_AGE=180
readonly STRAY_PROCESS_MIN_AGE_DAYS=1

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# Free space on the data volume, in whole gibibytes. Container Free Space is
# the true figure, because df counts snapshot-pinned blocks as used.
free_gib() {
  local bytes
  bytes=$(diskutil info "$DATA_VOLUME" 2>/dev/null \
    | awk -F'[()]' '/Container Free Space/ {print $2}' \
    | awk '{print $1}')
  if [ -n "$bytes" ]; then echo $((bytes / 1024 / 1024 / 1024)); else echo "?"; fi
}

# Run a command, or only announce it when DRY_RUN is set.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY RUN: $*"
    return 0
  fi
  "$@" >/dev/null 2>&1
}

# --- package manager caches -------------------------------------------------

# prune drops unreachable entries only, unlike clean, which drops everything.
prune_uv() {
  if ! command -v uv >/dev/null; then log "uv not installed, skipping"; return; fi
  log "pruning uv cache"
  run uv cache prune
}

prune_bun() {
  if ! command -v bun >/dev/null; then log "bun not installed, skipping"; return; fi
  log "clearing bun install cache"
  run bun pm cache rm
}

prune_npm() {
  if ! command -v npm >/dev/null; then log "npm not installed, skipping"; return; fi
  log "clearing npm cache"
  run npm cache clean --force
}

prune_homebrew() {
  if ! command -v brew >/dev/null; then log "brew not installed, skipping"; return; fi
  log "cleaning Homebrew and removing unused dependencies"
  run brew cleanup --prune=all
  run brew autoremove
}

# --- Xcode ------------------------------------------------------------------

# A simulator whose runtime no longer exists can never boot, so it is dead weight.
prune_simulators() {
  if ! command -v xcrun >/dev/null; then log "xcrun not installed, skipping"; return; fi
  log "deleting simulators with no matching runtime"
  run xcrun simctl delete unavailable
}

# DerivedData is a build cache. Xcode rebuilds whatever a project still needs.
prune_derived_data() {
  if [ ! -d "$DERIVED_DATA_DIR" ]; then log "no DerivedData, skipping"; return; fi
  local stale
  stale=$(find "$DERIVED_DATA_DIR" -maxdepth 1 -mindepth 1 -type d \
    -mtime "+$DERIVED_DATA_MAX_AGE" 2>/dev/null | wc -l | tr -d ' ')
  log "found $stale DerivedData folders older than $DERIVED_DATA_MAX_AGE days"
  if [ "$stale" = "0" ]; then return; fi
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY RUN: would remove $stale folders under $DERIVED_DATA_DIR"
    return
  fi
  find "$DERIVED_DATA_DIR" -maxdepth 1 -mindepth 1 -type d \
    -mtime "+$DERIVED_DATA_MAX_AGE" -exec rm -rf {} + 2>/dev/null
  log "removed $stale DerivedData folders"
}

# --- Spotlight --------------------------------------------------------------

# A node_modules tree holds thousands of small files that change on every
# install, which forces Spotlight to reindex constantly. The marker file stops
# that per folder. Unlike a .noindex suffix it leaves the directory name alone,
# so Node module resolution keeps working.
mark_node_modules() {
  if [ ! -d "$PROJECTS_DIR" ]; then log "no Projects directory, skipping"; return; fi
  local marked=0 dir
  while IFS= read -r dir; do
    if [ -e "$dir/$SPOTLIGHT_MARKER" ]; then continue; fi
    if [ "$DRY_RUN" = "1" ]; then
      marked=$((marked + 1))
      continue
    fi
    if touch "$dir/$SPOTLIGHT_MARKER" 2>/dev/null; then marked=$((marked + 1)); fi
  done < <(find "$PROJECTS_DIR" -type d -name node_modules -prune 2>/dev/null)
  log "added Spotlight marker to $marked new node_modules directories"
}

# --- Claude Code ------------------------------------------------------------

# Session transcripts are the record of past conversations, and claude --resume
# reads them. Only the genuinely old ones go.
prune_session_logs() {
  if [ ! -d "$SESSION_LOG_DIR" ]; then log "no Claude session logs, skipping"; return; fi
  local stale
  stale=$(find "$SESSION_LOG_DIR" -name '*.jsonl' \
    -mtime "+$SESSION_LOG_MAX_AGE" 2>/dev/null | wc -l | tr -d ' ')
  log "found $stale session transcripts older than $SESSION_LOG_MAX_AGE days"
  if [ "$stale" = "0" ]; then return; fi
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY RUN: would remove $stale transcripts under $SESSION_LOG_DIR"
    return
  fi
  find "$SESSION_LOG_DIR" -name '*.jsonl' -mtime "+$SESSION_LOG_MAX_AGE" -delete 2>/dev/null
  log "removed $stale session transcripts"
}

# --- staged installers ------------------------------------------------------

# Electron apps stage a full downloaded installer under ShipIt or a *-updater
# folder and never remove it after applying the update. Roughly 1.4 GB on this
# machine, and no cleanup tool surveyed touches it.
prune_staged_installers() {
  local freed=0 dir
  for dir in "$HOME"/Library/Caches/*ShipIt* "$HOME"/Library/Caches/*-updater; do
    [ -d "$dir" ] || continue
    local size
    size=$(du -sm "$dir" 2>/dev/null | awk '{print $1}')
    [ -z "$size" ] && continue
    if [ "$DRY_RUN" = "1" ]; then
      log "DRY RUN: would remove ${size} MB from $(basename "$dir")"
      freed=$((freed + size))
      continue
    fi
    rm -rf "$dir" 2>/dev/null && freed=$((freed + size))
  done
  log "reclaimed ${freed} MB of staged Electron installers"
}

# --- superseded agent binaries ----------------------------------------------

# Auto-updating CLI agents keep every version they have installed, at roughly
# 220 MB each. Nothing prunes them. Keep the two newest so a rollback is still
# possible, because the newest one is occasionally broken.
readonly AGENT_VERSIONS_TO_KEEP=2

prune_agent_versions() {
  local base agent entry count removed=0 in_use pid
  for agent in claude opencode cursor-agent; do
    base="$HOME/.local/share/$agent/versions"
    [ -d "$base" ] || continue

    # A version is a plain executable for some agents and a directory for
    # others, so match both rather than assuming one shape.
    count=$(find "$base" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -le "$AGENT_VERSIONS_TO_KEEP" ] && continue

    # A running session holds its own version open, and that version is not
    # always among the newest. Removing it would pull the binary out from under
    # live processes, so collect what is in use and never touch it.
    in_use=""
    for pid in $(pgrep -x "$agent" 2>/dev/null); do
      in_use="$in_use$(lsof -p "$pid" 2>/dev/null | awk -v b="$base" '$NF ~ b {print $NF}')
"
    done

    # Sort by version string, newest first, so a reinstall of an older version
    # does not look like the newest the way an mtime sort would make it. BSD
    # head rejects a negative count, hence skip-from-the-front rather than
    # drop-from-the-end.
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      if printf '%s' "$in_use" | grep -qxF "$entry"; then
        log "keeping $agent $(basename "$entry"), in use by a running session"
        continue
      fi
      if [ "$DRY_RUN" = "1" ]; then
        log "DRY RUN: would remove $agent version $(basename "$entry")"
      else
        rm -rf "$entry" 2>/dev/null
      fi
      removed=$((removed + 1))
    done < <(find "$base" -maxdepth 1 -mindepth 1 2>/dev/null \
      | sort -Vr | tail -n "+$((AGENT_VERSIONS_TO_KEEP + 1))")
  done
  log "removed $removed superseded agent versions"
}

# --- simulator caches -------------------------------------------------------

# This path sits outside $HOME, so every `du ~` sweep misses it. The runtime
# disk images alongside it are in use, so only Caches goes.
prune_simulator_caches() {
  local dir="/Library/Developer/CoreSimulator/Caches"
  [ -d "$dir" ] || { log "no CoreSimulator caches, skipping"; return; }
  local size
  size=$(du -sm "$dir" 2>/dev/null | awk '{print $1}')
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY RUN: would remove ${size:-?} MB from $dir (needs sudo)"
    return
  fi
  # Owned by root, so this only succeeds when the script runs with privileges.
  if rm -rf "$dir"/* 2>/dev/null; then
    log "reclaimed ${size:-?} MB of CoreSimulator caches"
  else
    log "CoreSimulator caches need sudo: sudo rm -rf $dir/*  (${size:-?} MB)"
  fi
}

# --- snapshots --------------------------------------------------------------

# This is the step that makes every deletion above visible. A local snapshot
# retains the blocks of every file deleted since it was taken, so a cleanup on
# a snapshotted volume can free tens of gigabytes and move the free-space
# figure by nothing. Thinning needs root, so this reports rather than acts.
report_snapshots() {
  local count
  count=$(tmutil listlocalsnapshots /System/Volumes/Data 2>/dev/null | grep -c 'com.apple' || echo 0)
  log "local snapshots: $count"
  if [ "$count" -gt 0 ]; then
    log "         the space freed above stays pinned until these thin out"
    log "         to reclaim it now: sudo tmutil thinlocalsnapshots /System/Volumes/Data 21474836480 4"
  fi
}

# --- stray processes --------------------------------------------------------

# A wedged child of a long-lived agent session never exits on its own. This
# only reports, because deciding what is finished needs a human. An etime
# holding a dash means the process is at least a day old.

# Walk up the parent chain and report whether it still reaches a live agent or
# terminal. Idleness alone proves nothing, because an MCP server is supposed to
# sit at 0% CPU for days. A genuine orphan is one whose parent chain is broken,
# which happens when the agent exits and the kernel reparents the child to
# PID 1. Claude Code allows a 90 ms grace period between SIGTERM signals, so
# any wrapper such as uv, npx, or npm exec loses the race and leaks its child.
has_live_ancestor() {
  local pid="$1" depth=0 name
  while [ -n "$pid" ] && [ "$pid" != "1" ] && [ "$pid" != "0" ] && [ "$depth" -lt 12 ]; do
    name=$(ps -o comm= -p "$pid" 2>/dev/null | sed 's|.*/||')
    case "$name" in
      claude|tmux|fish|zsh|bash|ghostty|Code|Cursor) return 0 ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    depth=$((depth + 1))
  done
  return 1
}

report_stray_processes() {
  local found=0 pid ppid etime name
  while read -r pid ppid etime name; do
    # An etime containing a dash means the process is at least a day old.
    case "$etime" in *-*) ;; *) continue ;; esac
    if has_live_ancestor "$ppid"; then continue; fi
    found=$((found + 1))
    log "WARNING: orphan pid=$pid ($name), age $etime, no live parent"
  done < <(ps -Ao pid=,ppid=,etime=,comm= \
    | sed 's|/[^ ]*/||' \
    | awk '$4 == "uv" || $4 == "python" || $4 == "python3" || $4 == "node"')

  if [ "$found" = "0" ]; then
    log "no orphaned build processes found"
  else
    log "         reap them with: kill $found orphan(s) listed above"
  fi
}

main() {
  local before after
  before=$(free_gib)
  log "=== cache cleanup starting (free: ${before} GiB) ==="
  if [ "$DRY_RUN" = "1" ]; then log "DRY RUN — nothing will be deleted"; fi

  prune_uv
  prune_bun
  prune_npm
  prune_homebrew
  prune_simulators
  prune_derived_data
  prune_staged_installers
  prune_agent_versions
  prune_simulator_caches
  mark_node_modules
  prune_session_logs
  report_stray_processes
  # Last, because it tells you how much of the above is still pinned.
  report_snapshots

  after=$(free_gib)
  log "=== done (free: ${before} GiB -> ${after} GiB) ==="
}

main "$@"
