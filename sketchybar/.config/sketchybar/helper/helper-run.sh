#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
BINARY="$SCRIPT_DIR/helper"
BOOTSTRAP="${1:?usage: helper-run.sh <bootstrap-name>}"
SERVICE=homebrew.mxcl.sketchybar
CACHE_DIR="$HOME/Library/Caches/sketchybar"
RECOVERY_GUARD="$CACHE_DIR/helper-recovery"
PARENT_READY_FIFO="${SKETCHYBAR_HELPER_READY_FIFO:?ready fifo required}"
READY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-helper-child-ready.XXXXXX")" || exit 1
READY_FIFO="$READY_DIR/ready"
child_pid=
stopping=false
ready=false

stop_child() {
  local attempt
  stopping=true
  [ -n "$child_pid" ] || return
  kill -TERM "$child_pid" 2>/dev/null || return
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$child_pid" 2>/dev/null || return
    sleep 0.1
  done
  kill -KILL "$child_pid" 2>/dev/null || true
}
trap stop_child HUP INT TERM
trap 'rm -rf "$READY_DIR"' EXIT

mkfifo -m 600 "$READY_FIFO" || exit 1
exec 9<>"$READY_FIFO"
started="$(date +%s)"
SKETCHYBAR_HELPER_READY_FIFO="$READY_FIFO" "$BINARY" "$BOOTSTRAP" 9>&- &
child_pid=$!

if IFS= read -r -t 4 signal <&9 && [ "$signal" = ready ]; then
  ready=true
  printf 'ready\n' > "$PARENT_READY_FIFO" || stop_child
fi

wait "$child_pid"
code=$?
uptime=$(( $(date +%s) - started ))

$stopping && exit 0
case "$code" in
  0) exit 0 ;;
esac

# A failed cold start should stay failed. After ready, allow at most one
# automatic paired restart per five-minute healthy interval.
$ready || exit "$code"
[ "$uptime" -lt 300 ] || rmdir "$RECOVERY_GUARD" 2>/dev/null || true
if mkdir "$RECOVERY_GUARD" 2>/dev/null; then
  for _ in 1 2 3; do
    $stopping && exit 0
    launchctl kickstart -k "gui/$(id -u)/$SERVICE" && exit "$code"
    sleep 0.5
  done
  printf 'sketchybar helper recovery failed; restart SketchyBar manually\n' >&2
else
  printf 'sketchybar helper recovery suppressed after repeated failure\n' >&2
fi
exit "$code"
