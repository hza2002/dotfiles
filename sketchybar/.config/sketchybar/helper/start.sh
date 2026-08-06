#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
BINARY="$SCRIPT_DIR/helper"
WRAPPER="$SCRIPT_DIR/helper-run.sh"
BOOTSTRAP=git.felix.helper
SERVICE=homebrew.mxcl.sketchybar
USER_UID="$(id -u)"
CACHE_DIR="$HOME/Library/Caches/sketchybar"
LOG="$CACHE_DIR/helper.log"

if [ "$#" -ne 0 ]; then
  printf 'usage: %s\n' "$0" >&2
  exit 64
fi

if [ ! -x "$BINARY" ]; then
  printf 'sketchybar helper is missing; run make in %s\n' "$SCRIPT_DIR" >&2
  exit 1
fi

umask 077
[ ! -L "$CACHE_DIR" ] || exit 1
mkdir -p "$CACHE_DIR" || exit 1
chmod 700 "$CACHE_DIR" || exit 1

exec 8>"$CACHE_DIR/helper-start.lock" || exit 1
/usr/bin/lockf -s -t 5 8 || exit 1

helper_pair_running() {
  local bar_pids helper_pids wrapper_pids bar_pid helper_pid wrapper_pid bar_pgid
  bar_pids="$(pgrep -U "$USER_UID" -x sketchybar || true)"
  helper_pids="$(pgrep -U "$USER_UID" -fx "$BINARY $BOOTSTRAP" || true)"
  wrapper_pids="$(pgrep -U "$USER_UID" -fx "/bin/bash $WRAPPER $BOOTSTRAP" || true)"
  case "$bar_pids:$helper_pids:$wrapper_pids" in
    *$'\n'*|:*) return 1 ;;
  esac
  bar_pid="$bar_pids"
  helper_pid="$helper_pids"
  wrapper_pid="$wrapper_pids"
  bar_pgid="$(ps -o pgid= -p "$bar_pid" 2>/dev/null | tr -d ' ')"
  [ -n "$bar_pid" ] && [ -n "$helper_pid" ] && [ -n "$wrapper_pid" ] \
    && [ -n "$bar_pgid" ] \
    && [ "$(ps -o ppid= -p "$helper_pid" 2>/dev/null | tr -d ' ')" = "$wrapper_pid" ] \
    && [ "$(ps -o pgid= -p "$helper_pid" 2>/dev/null | tr -d ' ')" = "$bar_pgid" ] \
    && [ "$(ps -o pgid= -p "$wrapper_pid" 2>/dev/null | tr -d ' ')" = "$bar_pgid" ]
}

matching_helper_pids() {
  pgrep -U "$USER_UID" -fx "$BINARY $BOOTSTRAP" || true
}

matching_wrapper_pids() {
  pgrep -U "$USER_UID" -fx "/bin/bash $WRAPPER $BOOTSTRAP" || true
}

stop_inconsistent_pair() {
  local pid
  for pid in $(matching_wrapper_pids) $(matching_helper_pids); do
    kill -TERM "$pid" 2>/dev/null || true
  done
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [ -z "$(matching_wrapper_pids)$(matching_helper_pids)" ] && return 0
    sleep 0.1
  done
  for pid in $(matching_wrapper_pids) $(matching_helper_pids); do
    kill -KILL "$pid" 2>/dev/null || true
  done
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -z "$(matching_wrapper_pids)$(matching_helper_pids)" ] && return 0
    sleep 0.1
  done
  return 1
}

# A config reload can reuse the manually managed helper. Updating the binary
# takes effect after explicitly restarting SketchyBar.
if helper_pair_running; then
  exit 0
fi

if [ -n "$(matching_helper_pids)$(matching_wrapper_pids)" ]; then
  printf 'sketchybar helper pair is inconsistent; restarting SketchyBar\n' >&2
  if ! stop_inconsistent_pair; then
    printf 'unable to stop inconsistent SketchyBar helper pair\n' >&2
    exit 1
  fi
  launchctl kickstart -k "gui/$USER_UID/$SERVICE"
  exit 1
fi

READY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-helper-ready.XXXXXX")" || exit 1
READY_FIFO="$READY_DIR/ready"
wrapper_pid=

cleanup() {
  rm -rf "$READY_DIR"
}

job_is_running() {
  local pid
  for pid in $(jobs -pr); do
    [ "$pid" = "$1" ] && return 0
  done
  return 1
}
trap cleanup EXIT HUP INT TERM

mkfifo -m 600 "$READY_FIFO" || exit 1
exec 9<>"$READY_FIFO"
SKETCHYBAR_HELPER_READY_FIFO="$READY_FIFO" \
  "$WRAPPER" "$BOOTSTRAP" >> "$LOG" 2>&1 8>&- 9>&- &
wrapper_pid=$!

if IFS= read -r -t 5 ready <&9 && [ "$ready" = ready ]; then
  exit 0
fi

printf 'sketchybar helper failed to become ready; see %s\n' "$LOG" >&2
if job_is_running "$wrapper_pid"; then
  kill -TERM "$wrapper_pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    job_is_running "$wrapper_pid" || break
    sleep 0.1
  done
  job_is_running "$wrapper_pid" && kill -KILL "$wrapper_pid" 2>/dev/null || true
fi
wait "$wrapper_pid" 2>/dev/null || true
exit 1
