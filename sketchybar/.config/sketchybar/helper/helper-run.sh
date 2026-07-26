#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=runtime.sh
source "$SCRIPT_DIR/runtime.sh"

BINARY="$SCRIPT_DIR/helper"
BOOTSTRAP="${1:?usage: helper-run.sh <bootstrap-name>}"
SERVICE=homebrew.mxcl.sketchybar
child_pid=
stopping=false

[ "$#" -eq 1 ] || exit 64
helper_runtime_init || exit 1

forward_signal() {
  stopping=true
  [ -n "${child_pid:-}" ] && kill -TERM "$child_pid" 2>/dev/null || true
}
trap forward_signal TERM HUP INT

request_recovery() {
  local code="${1:?code required}" uptime="${2:?uptime required}"
  local marker="$HELPER_RUNTIME_DIR/install-in-progress"
  local failures status reason ks_rc

  while :; do
    while [ -e "$marker" ] && helper_marker_valid; do
      sleep 0.2
    done

    exec 7>"$HELPER_RUNTIME_DIR/recovery.lock" || return 1
    if ! /usr/bin/lockf -s -t 10 7; then
      helper_log "level=error event=recovery-lock-timeout code=$code uptime=$uptime"
      return 1
    fi
    if [ -e "$marker" ] && helper_marker_valid; then
      exec 7>&-
      continue
    fi
    break
  done

  helper_state_read >/dev/null 2>&1 || true
  failures="$HELPER_RECOVERY_FAILURES"
  status="$HELPER_RECOVERY_STATUS"
  reason=unexpected-helper-exit

  if [ "$status" = open ]; then
    failures=2
    reason=degraded-transition
  else
    if [ "$uptime" -ge 300 ]; then
      failures=0
    fi
    failures=$((failures + 1))
    if [ "$failures" -ge 2 ]; then
      failures=2
      status=open
    fi
    if ! helper_state_write "$status" "$failures"; then
      helper_log "level=error event=recovery-state-write-failed code=$code uptime=$uptime failures=$failures"
      exec 7>&-
      return 1
    fi
  fi

  helper_log "level=warning event=recovery-request reason=$reason code=$code uptime=$uptime failures=$failures circuit=$status service_pid=$(helper_service_field pid) runs=$(helper_service_field runs)"
  launchctl kickstart -k "gui/$(id -u)/$SERVICE" 7>&-
  ks_rc=$?
  if [ "$ks_rc" -ne 0 ]; then
    helper_log "level=error event=recovery-request-failed rc=$ks_rc code=$code uptime=$uptime failures=$failures circuit=$status"
  fi
  exec 7>&-
  return "$ks_rc"
}

helper_log "level=info event=launch wrapper_pid=$$"
started="$(date +%s)"
"$BINARY" "$BOOTSTRAP" &
child_pid=$!
wait "$child_pid"
code=$?
uptime=$(( $(date +%s) - started ))

if $stopping; then
  wait "$child_pid" 2>/dev/null || true
  helper_log "level=info event=stopped wrapper_pid=$$"
  exit 0
fi

case "$code" in
  0|143)
    helper_log "level=info event=helper-exit code=$code uptime=$uptime recovery=none"
    exit 0
    ;;
esac

helper_log "level=error event=helper-exit code=$code uptime=$uptime recovery=pending"
request_recovery "$code" "$uptime"
