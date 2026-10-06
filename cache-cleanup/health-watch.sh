#!/usr/bin/env bash
#
# Early warning for the failure modes that made this Mac unusable in August
# 2026. Runs every 30 minutes from com.dvicente.health-watch.plist.
#
# The metrics here were chosen from the XNU compressor sources, not from the
# numbers Activity Monitor makes prominent. Three figures that look alarming
# are deliberately NOT alerted on, because the kernel ignores them too:
#
#   - "Pages occupied by compressor". macOS holds a target ratio of
#     uncompressed to total memory, so a large compressor is the design
#     working, not a fault.
#   - Swap used, and the number of swap files. Neither appears in any kernel
#     pressure calculation.
#   - Cumulative Pageouts and Swapouts. Monotonic counters since boot, so they
#     only ever describe an average and hide every real stall.
#
# What the kernel actually gates on is the ratio of uncompressed memory to
# uncompressed-plus-compressor, called ANC below. What actually blocks a thread
# is a fault on a page that lives in a swapped-out compressor segment, which
# the swapins counter measures.

set -uo pipefail

readonly DATA_VOLUME="/System/Volumes/Data"
readonly NOTIFY_TITLE="Mac health"
readonly PAGE_SIZE=16384

# Set NOTIFY=0 to silence every desktop notification and keep only the log.
readonly NOTIFY="${NOTIFY:-1}"

# Disk. macOS 26 wants 15 to 20 percent free for swap growth and APFS metadata.
readonly MIN_FREE_PERCENT=20

# ANC headroom, as a percentage. The kernel's own transitions: below 50 it
# warns, below 34.3 it goes critical, below 28.6 the swapper stops throttling
# itself, and below 18 page faults get throttled and the machine beachballs.
# Alert at 34 so there is room to act before the cliff.
readonly MIN_ANC_PERCENT=34

# Swapin rate, in pages per second. Under 100 is nothing. Sustained above 1000
# produces visible stalls. Above 5000 produces beachballs.
readonly MAX_SWAPINS_PER_SEC=1000

# launchd appends to StandardOutPath forever and never rotates it. A week of
# half-hourly runs came to 116 KB, so truncate rather than grow without bound.
readonly LOG_FILE="$HOME/Library/Logs/health-watch.log"
readonly MAX_LOG_BYTES=524288

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# Keep the newest half of the log when it outgrows the cap.
rotate_log() {
  [ -f "$LOG_FILE" ] || return 0
  local size
  size=$(stat -f%z "$LOG_FILE" 2>/dev/null) || return 0
  [ "$size" -le "$MAX_LOG_BYTES" ] && return 0
  local keep
  keep=$(tail -n 500 "$LOG_FILE" 2>/dev/null)
  printf '%s\n' "$keep" > "$LOG_FILE" 2>/dev/null
  log "log truncated at ${size} bytes, kept the last 500 lines"
}

# osascript needs no dependency, unlike terminal-notifier. A notification is
# reserved for a state that is both abnormal and actionable. Anything that is
# merely worth knowing goes through log() instead, because an alert that fires
# on every run trains you to ignore the one that matters.
notify() {
  log "ALERT: $1"
  [ "$NOTIFY" = "1" ] || return 0
  osascript -e "display notification \"$1\" with title \"$NOTIFY_TITLE\" sound name \"Basso\"" 2>/dev/null
}

# df is trustworthy for free space. Finder and System Settings are not, because
# both omit purgeable space and can be wrong by tens of gigabytes.
free_percent() {
  df "$DATA_VOLUME" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print 100-$5}'
}

# grep -c already prints 0 when it matches nothing, but it also exits 1, so a
# `|| echo 0` fallback would print a second zero and break every later test.
# Under launchd tmutil can also fail outright, hence the digits-only guard.
snapshot_count() {
  local n
  n=$(tmutil listlocalsnapshots "$DATA_VOLUME" 2>/dev/null | grep -c 'com.apple')
  case "$n" in
    ''|*[!0-9]*) echo 0 ;;
    *) echo "$n" ;;
  esac
}

check_disk() {
  local free
  free=$(free_percent)
  if [ -z "$free" ]; then log "could not read free space, skipping"; return; fi
  log "disk: ${free}% free"
  if [ "$free" -lt "$MIN_FREE_PERCENT" ]; then
    notify "Disk ${free}% free, below ${MIN_FREE_PERCENT}%. $(snapshot_count) snapshots may be pinning deleted files."
  fi
}

# Log only, never notify. Time Machine keeps roughly 24 hourly snapshots by
# design and thins them itself, so a count in the twenties is normal and not a
# fault. The count still belongs in the log, because it explains why a cleanup
# freed space the free-space figure does not show.
check_snapshots() {
  local count
  count=$(snapshot_count)
  log "snapshots: $count (normal is up to ~24 hourly; they pin deleted files until thinned)"
}

# ANC over AVAILABLE, the ratio the kernel gates swapout and pressure on.
check_memory_headroom() {
  local pct
  pct=$(vm_stat 2>/dev/null | awk -v ps="$PAGE_SIZE" '
    /Pages active/            {a=$3}
    /Pages inactive/          {i=$3}
    /Pages free/              {f=$3}
    /Pages speculative/       {s=$3}
    /Pages occupied by compressor/ {c=$5}
    END { anc=a+i+f+s; am=anc+c; if (am>0) printf "%.0f", anc*100/am }')
  local level
  level=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)
  if [ -z "$pct" ]; then log "could not read memory headroom, skipping"; return; fi
  log "memory: ANC ${pct}% headroom, pressure level ${level:-?} (1 normal, 2 warn, 4 critical)"
  if [ "$pct" -lt "$MIN_ANC_PERCENT" ]; then
    notify "Memory headroom ${pct}%, near the kernel's critical threshold. Close idle sessions."
  fi
  if [ "${level:-1}" = "4" ]; then
    notify "Kernel reports CRITICAL memory pressure. Quit the largest processes now."
  fi
}

# Swapins are demand-paged reads of compressed segments from the SSD. A thread
# waiting on one is a thread that has stopped. This is the honest latency signal.
check_swapin_rate() {
  local rate
  # vm_stat -c prints a title, a header, one CUMULATIVE row, then the deltas.
  # Averaging the cumulative row reports a fake rate in the hundreds of
  # thousands, so the per-second samples start at line 4.
  rate=$(vm_stat -c 4 1 2>/dev/null | awk 'NR>3 {n++; s+=$(NF-1)} END {if (n>0) printf "%.0f", s/n}')
  if [ -z "$rate" ]; then log "could not sample swapin rate, skipping"; return; fi
  log "swapins: ${rate} pages/sec (under 100 idle, over ${MAX_SWAPINS_PER_SEC} means stalls)"
  if [ "$rate" -gt "$MAX_SWAPINS_PER_SEC" ]; then
    notify "Swapping in ${rate} pages/sec. The machine is thrashing, not merely busy."
  fi
}

# Swapouts are asynchronous background writes. They do not block you, so this
# check exists only to flag sustained SSD wear.
check_swapout_rate() {
  local pages gib days rate boot now
  pages=$(vm_stat 2>/dev/null | awk '/Swapouts/ {gsub(/\./,"",$2); print $2}')
  boot=$(sysctl -n kern.boottime 2>/dev/null | awk '{gsub(/,/,"",$4); print $4}')
  now=$(date +%s)
  if [ -z "$pages" ] || [ -z "$boot" ]; then log "could not read swapout counters, skipping"; return; fi
  local uptime_sec=$((now - boot))
  if [ "$uptime_sec" -lt 3600 ]; then log "swapout rate: too early to judge"; return; fi
  gib=$(awk -v p="$pages" -v ps="$PAGE_SIZE" 'BEGIN {printf "%.1f", p*ps/1073741824}')
  days=$(awk -v s="$uptime_sec" 'BEGIN {printf "%.2f", s/86400}')
  rate=$(awk -v g="$gib" -v d="$days" 'BEGIN {printf "%.0f", g/d}')
  # Log only, never notify. This machine's normal range is 20 to 43 GiB/day,
  # so any threshold near the baseline fires constantly. Swapouts are also
  # asynchronous background writes that never block a thread, which makes this
  # a slow-burn SSD-wear figure rather than something to act on today. Read it
  # from the log across weeks, not from a notification.
  log "swapouts: ${gib} GiB over ${days} days = ${rate} GiB/day (SSD wear trend, not slowness)"
}

# ps reports resident memory only, and most of a long-lived agent session is
# already swapped out. Resident plus swapped is the real demand, so vmmap is
# the only honest instrument. It is slow, so this only counts sessions.
check_agent_sessions() {
  local count
  count=$(pgrep -x claude 2>/dev/null | wc -l | tr -d ' ')
  log "claude sessions: $count (measure true demand with: vmmap -summary <pid>)"
}

main() {
  rotate_log
  log "=== health check ==="
  check_disk
  check_snapshots
  check_memory_headroom
  check_swapin_rate
  check_swapout_rate
  check_agent_sessions
  log "=== done ==="
}

main "$@"
