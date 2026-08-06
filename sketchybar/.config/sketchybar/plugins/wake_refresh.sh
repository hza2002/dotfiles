#!/bin/bash

# Rebuild the bar surface after a real system wake.
# Toggling the display target forces a window destroy/recreate, replacing the
# invalid CoreGraphics context that can survive sleep.

CACHE_DIR="$HOME/Library/Caches/sketchybar"
LOCK="$CACHE_DIR/wake-refresh.lock"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-sketchybar}"

umask 077
[ ! -L "$CACHE_DIR" ] || exit 1
mkdir -p "$CACHE_DIR" || exit 1
chmod 700 "$CACHE_DIR" || exit 1

now_ms() {
  /usr/bin/perl -MTime::HiRes=time -e 'printf "%d\n", time() * 1000' 2>/dev/null \
    || printf '%s000\n' "$(date +%s)"
}

log_event() {
  # Logging is diagnostic only and must never prevent surface recovery.
  printf 'ts=%s level=info incident=%s component=wake_refresh event=%s %s\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
    "$INCIDENT" \
    "${SENDER:-manual}" \
    "$*" >&2
}

run_display_change() {
  local display="$1" started finished

  started="$(now_ms)"
  "$SKETCHYBAR_BIN" --bar "display=$display"
  DISPLAY_RC=$?
  finished="$(now_ms)"
  DISPLAY_DURATION_MS=$((finished - started))
  return "$DISPLAY_RC"
}

case "${SENDER:-}" in
  system_woke) ;;
  *) exit 0 ;;
esac

# A full system wake can emit both subscribed events. Serialize them so only
# one window rebuild runs at a time; lockf releases the lock even if killed.
if [ "${1:-}" != "--locked" ]; then
  /usr/bin/lockf -s -k -t 0 "$LOCK" "$0" --locked
  lock_rc=$?
  [ "$lock_rc" -eq 75 ] && exit 0
  exit "$lock_rc"
fi

INCIDENT="$(now_ms)-$$"
total_started="$(now_ms)"
log_event "phase=received pid=$$"

run_display_change main
main_rc=$?
main_duration_ms=$DISPLAY_DURATION_MS

all_rc=skipped
all_duration_ms=0
if [ "$main_rc" -eq 0 ]; then
  run_display_change all
  all_rc=$?
  all_duration_ms=$DISPLAY_DURATION_MS
fi

rc=$main_rc
[ "$main_rc" -eq 0 ] && rc=$all_rc
total_finished="$(now_ms)"
log_event "phase=completed main_duration_ms=$main_duration_ms main_rc=$main_rc all_duration_ms=$all_duration_ms all_rc=$all_rc duration_ms=$((total_finished - total_started)) rc=$rc"
exit "$rc"
