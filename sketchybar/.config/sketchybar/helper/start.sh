#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=runtime.sh
source "$SCRIPT_DIR/runtime.sh"

BOOTSTRAP=git.felix.helper
BINARY="$SCRIPT_DIR/helper"
WRAPPER="$SCRIPT_DIR/helper-run.sh"
READY_TIMEOUT="${SKETCHYBAR_HELPER_READY_TIMEOUT:-5}"
STARTUP_LOCK_TIMEOUT=$((READY_TIMEOUT + 15))

helper_runtime_init || exit 1

if [ "$#" -ne 0 ]; then
  helper_log "level=error event=start-usage-error"
  exit 64
fi

CONFIG_ROOT=
if [ -n "${CONFIG_DIR:-}" ] && [ -d "$CONFIG_DIR" ]; then
  CONFIG_ROOT="$(cd "$CONFIG_DIR" && pwd -P)"
fi
if [ "$CONFIG_ROOT" != "${SCRIPT_DIR%/helper}" ] || [ "${BAR_NAME:-}" != sketchybar ]; then
  helper_log "level=error event=deployment-mismatch config_dir=${CONFIG_DIR:-unset} bar_name=${BAR_NAME:-unset}"
  exit 1
fi

exec 8>"$HELPER_RUNTIME_DIR/startup.lock" || exit 1
if ! /usr/bin/lockf -s -t "$STARTUP_LOCK_TIMEOUT" 8; then
  helper_log "level=error event=startup-lock-timeout timeout=$STARTUP_LOCK_TIMEOUT"
  exit 1
fi

exec 7>"$HELPER_RUNTIME_DIR/recovery.lock" || exit 1
if ! /usr/bin/lockf -s -t 5 7; then
  helper_log "level=error event=recovery-lock-timeout phase=startup"
  exit 1
fi
helper_state_read >/dev/null 2>&1 || true
if [ "$HELPER_RECOVERY_STATUS" = open ] && ! helper_marker_valid; then
  helper_state_write open 2 || {
    helper_log "level=error event=circuit-state-write-failed phase=degraded-startup"
    exit 1
  }
  exec 7>&-
  exec 8>&-
  helper_log "level=warning event=circuit-open action=helper-skipped"
  exit 1
fi
exec 7>&-

if [ ! -x "$BINARY" ]; then
  exec 8>&-
  helper_log "level=warning event=binary-missing action=run-helper-install"
  exit 1
fi

if helper_exact_pair "$BINARY" "$WRAPPER" "$BOOTSTRAP"; then
  exec 8>&-
  helper_log "level=info event=pair-adopted"
  exit 0
fi

READY_FIFO="$HELPER_RUNTIME_DIR/ready.$$"
rm -f "$READY_FIFO"
if ! mkfifo -m 600 "$READY_FIFO"; then
  exec 8>&-
  helper_log "level=error event=ready-fifo-create-failed"
  exit 1
fi

wrapper_pid=
cleanup() {
  rm -f "$READY_FIFO"
}
trap cleanup EXIT HUP INT TERM
exec 9<>"$READY_FIFO"

SKETCHYBAR_HELPER_RUNTIME_DIR="$HELPER_RUNTIME_DIR" \
SKETCHYBAR_HELPER_READY_FIFO="$READY_FIFO" \
  "$WRAPPER" "$BOOTSTRAP" 7>&- 8>&- 9>&- &
wrapper_pid=$!

if IFS= read -r -t "$READY_TIMEOUT" ready <&9 && [ "$ready" = ready ]; then
  exec 9<&-
  exec 9>&-
  rm -f "$READY_FIFO"
  trap - EXIT HUP INT TERM
  if helper_exact_pair "$BINARY" "$WRAPPER" "$BOOTSTRAP"; then
    exec 8>&-
    helper_log "level=info event=pair-ready wrapper_pid=$wrapper_pid"
    exit 0
  fi
  helper_log "level=error event=pair-validation-failed wrapper_pid=$wrapper_pid"
else
  helper_log "level=error event=ready-timeout wrapper_pid=$wrapper_pid timeout=$READY_TIMEOUT"
fi

child_pid=
child_identity=
while read -r pid ppid command; do
  if [ "$ppid" = "$wrapper_pid" ] && [ "$command" = "$BINARY $BOOTSTRAP" ]; then
    child_pid="$pid"
    child_identity="$(helper_process_identity "$pid" 2>/dev/null || true)"
    break
  fi
done < <(ps -axo pid=,ppid=,command=)

[ -n "$child_pid" ] && kill -TERM "$child_pid" 2>/dev/null || true
kill -TERM "$wrapper_pid" 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  { ! kill -0 "$wrapper_pid" 2>/dev/null \
    && { [ -z "$child_pid" ] || ! kill -0 "$child_pid" 2>/dev/null; }; } && break
  sleep 0.1
done
if kill -0 "$wrapper_pid" 2>/dev/null; then
  kill -KILL "$wrapper_pid" 2>/dev/null || true
fi
if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null \
  && [ "$(helper_process_identity "$child_pid" 2>/dev/null || true)" = "$child_identity" ]; then
  kill -KILL "$child_pid" 2>/dev/null || true
fi
wait "$wrapper_pid" 2>/dev/null || true

child_gone=true
if [ -n "$child_pid" ]; then
  child_gone=false
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$child_pid" 2>/dev/null \
      || [ "$(helper_process_identity "$child_pid" 2>/dev/null || true)" != "$child_identity" ]; then
      child_gone=true
      break
    fi
    sleep 0.1
  done
fi
if ! $child_gone; then
  exec 7>"$HELPER_RUNTIME_DIR/recovery.lock" || true
  if /usr/bin/lockf -s -t 5 7; then
    helper_state_write open 2 || true
    exec 7>&-
  fi
  helper_log "level=error event=helper-termination-incomplete child_pid=$child_pid action=circuit-open"
fi
exec 8>&-
exit 1
