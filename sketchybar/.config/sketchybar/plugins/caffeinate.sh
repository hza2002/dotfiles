#!/bin/bash

# Single owner for the idle-system and display-sleep assertions used by
# SketchyBar. Public mutations serialize through one lock and one state file.

set -u

TEST_MODE=0
if [ "${1:-}" = "__test__" ]; then
  TEST_MODE=1
  shift
  case "${CAFFEINATE_TEST_ROOT:-}" in
    /*) ;;
    *) printf 'caffeinate: __test__ requires an absolute CAFFEINATE_TEST_ROOT\n' >&2; exit 64 ;;
  esac
fi

source "${CONFIG_DIR:?CONFIG_DIR is required}/colors.sh"
source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/spacing.sh"

IDLE_LABEL="按點下班"
HOURS_LABEL="加會兒班"
UNTIL_LABEL="加個夜班"
FOREVER_LABEL="不下班了"

if [ "$TEST_MODE" -eq 1 ]; then
  DATA_DIR="$CAFFEINATE_TEST_ROOT/state"
  LEGACY_DIR="$CAFFEINATE_TEST_ROOT/legacy"
  CAFFEINATE_BIN="${CAFFEINATE_TEST_CAFFEINATE:-/usr/bin/caffeinate}"
  SKETCHYBAR_BIN="${CAFFEINATE_TEST_SKETCHYBAR:-/opt/homebrew/bin/sketchybar}"
  PMSET_BIN="${CAFFEINATE_TEST_PMSET:-/usr/bin/pmset}"
  OSASCRIPT_BIN="${CAFFEINATE_TEST_OSASCRIPT:-/usr/bin/osascript}"
  OBSERVER_BIN="${CAFFEINATE_TEST_OBSERVER:-}"
  NOW_BIN="${CAFFEINATE_TEST_NOW:-}"
else
  DATA_DIR="$HOME/Library/Application Support/sketchybar"
  LEGACY_DIR="$HOME/Library/Caches/sketchybar"
  CAFFEINATE_BIN="/usr/bin/caffeinate"
  SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
  PMSET_BIN="/usr/bin/pmset"
  OSASCRIPT_BIN="/usr/bin/osascript"
  OBSERVER_BIN=""
  NOW_BIN=""
fi

STATE_FILE="$DATA_DIR/caffeinate.state"
PENDING_FILE="$DATA_DIR/caffeinate.pending"
OWNER_LOCK="$DATA_DIR/caffeinate.lock"
UI_LOCK="$DATA_DIR/caffeinate.ui.lock"
RECOVERY_LOCK="$DATA_DIR/caffeinate.recovery.lock"
DIAG_LOCK="$DATA_DIR/caffeinate.log.lock"
LOG_FILE="$DATA_DIR/caffeinate.log"
NOTICE_DIR="$DATA_DIR/notices"
LEGACY_STATE_FILE="$LEGACY_DIR/caffeinate.state"
LEGACY_LOCK="$LEGACY_DIR/caffeinate.lock"
SCRIPT_PATH="$CONFIG_DIR/plugins/caffeinate.sh"

umask 077
[ ! -L "$DATA_DIR" ] || exit 1
mkdir -p "$DATA_DIR" || exit 1
[ -d "$DATA_DIR" ] && [ ! -L "$DATA_DIR" ] || exit 1
chmod 700 "$DATA_DIR" || exit 1

safe_regular_path() {
  [ ! -L "$1" ] && { [ ! -e "$1" ] || [ -f "$1" ]; }
}

prepare_lock() {
  safe_regular_path "$1" || return 1
  : >>"$1" || return 1
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  chmod 600 "$1" || return 1
}

prepare_lock "$OWNER_LOCK" || exit 1
prepare_lock "$UI_LOCK" || exit 1
prepare_lock "$RECOVERY_LOCK" || exit 1
DIAG_ENABLED=1
DIAG_READY=0
DIAG_BASE_EPOCH=""
DIAG_BASE_SECONDS=""
prepare_lock "$DIAG_LOCK" || DIAG_ENABLED=0

now_epoch() {
  if [ "$TEST_MODE" -eq 1 ] && [ -n "$NOW_BIN" ]; then
    "$NOW_BIN"
  else
    /bin/date +%s
  fi
}

# Run an external command with a wall-clock deadline. Polling in the parent
# keeps timeout signaling local to this invocation; children never inherit the
# state locks.
run_bounded() {
  local timeout="$1" child rc i=0 limit
  shift
  "$@" 7>&- 8>&- 9>&- &
  child=$!
  limit=$((timeout * 100))
  while /bin/kill -0 "$child" 2>/dev/null && [ "$i" -lt "$limit" ]; do
    /bin/sleep 0.01
    i=$((i + 1))
  done
  if /bin/kill -0 "$child" 2>/dev/null; then
    /bin/kill -TERM "$child" 2>/dev/null || true
    i=0
    while /bin/kill -0 "$child" 2>/dev/null && [ "$i" -lt 100 ]; do
      /bin/sleep 0.01
      i=$((i + 1))
    done
    /bin/kill -0 "$child" 2>/dev/null \
      && /bin/kill -KILL "$child" 2>/dev/null || true
  fi
  wait "$child" 2>/dev/null
  rc=$?
  return "$rc"
}

run_capture() {
  local timeout="$1" output="$2" child rc i=0 limit
  shift 2
  "$@" >"$output" 2>/dev/null 7>&- 8>&- 9>&- &
  child=$!
  limit=$((timeout * 100))
  while /bin/kill -0 "$child" 2>/dev/null && [ "$i" -lt "$limit" ]; do
    /bin/sleep 0.01
    i=$((i + 1))
  done
  if /bin/kill -0 "$child" 2>/dev/null; then
    /bin/kill -TERM "$child" 2>/dev/null || true
    i=0
    while /bin/kill -0 "$child" 2>/dev/null && [ "$i" -lt 100 ]; do
      /bin/sleep 0.01
      i=$((i + 1))
    done
    /bin/kill -0 "$child" 2>/dev/null \
      && /bin/kill -KILL "$child" 2>/dev/null || true
  fi
  wait "$child" 2>/dev/null
  rc=$?
  return "$rc"
}

atomic_write() {
  local path="$1" content="$2" tmp
  safe_regular_path "$path" || return 1
  tmp=$(/usr/bin/mktemp "${path}.XXXXXX") || return 1
  chmod 600 "$tmp" || { /bin/rm -f "$tmp"; return 1; }
  if ! /usr/bin/printf '%s\n' "$content" >"$tmp" || ! /bin/mv -f "$tmp" "$path"; then
    /bin/rm -f "$tmp"
    return 1
  fi
}

# Persistent transition history for postmortems. Routine renders do not log.
log_event() {
  local event="$1" event_time entry entry_size size=0 keep tmp
  shift
  [ "$DIAG_ENABLED" -eq 1 ] || return 0
  if [ -z "$DIAG_BASE_EPOCH" ]; then
    DIAG_BASE_EPOCH=$(now_epoch 2>/dev/null || /bin/date +%s)
    DIAG_BASE_SECONDS=$SECONDS
  fi
  event_time=$((DIAG_BASE_EPOCH + SECONDS - DIAG_BASE_SECONDS))
  printf -v entry 'ts=%s pid=%s event=%s %s' "$event_time" "$$" "$event" "$*"
  entry_size=$((${#entry} + 1))
  [ "$entry_size" -lt 131072 ] 2>/dev/null || return 0
  exec 6>>"$DIAG_LOCK" || return 0
  /usr/bin/lockf -s -t 0 6 || { exec 6>&-; return 0; }
  safe_regular_path "$LOG_FILE" || { exec 6>&-; return 0; }
  if [ "$DIAG_READY" -eq 0 ] && [ -e "$LOG_FILE" ]; then
    chmod 600 "$LOG_FILE" || { exec 6>&-; return 0; }
    DIAG_READY=1
  fi
  if [ -e "$LOG_FILE" ]; then
    size=$(/usr/bin/stat -f %z "$LOG_FILE" 2>/dev/null || /usr/bin/printf '0')
  fi
  if [ "$((size + entry_size))" -gt 131072 ] 2>/dev/null; then
    tmp=$(/usr/bin/mktemp "${LOG_FILE}.XXXXXX") || { exec 6>&-; return 0; }
    chmod 600 "$tmp" || { /bin/rm -f "$tmp"; exec 6>&-; return 0; }
    keep=$((131072 - entry_size))
    if ! ( set -o pipefail
        /usr/bin/tail -n 400 "$LOG_FILE" 2>/dev/null \
          | /usr/bin/tail -c "$keep" 2>/dev/null | /usr/bin/sed '1d' >"$tmp"
      ) \
        || ! /bin/mv -f "$tmp" "$LOG_FILE"; then
      /bin/rm -f "$tmp"
      exec 6>&-
      return 0
    fi
  fi
  if ! /usr/bin/printf '%s\n' "$entry" >>"$LOG_FILE" 2>/dev/null; then
    exec 6>&-
    return 0
  fi
  if [ "$DIAG_READY" -eq 0 ]; then
    chmod 600 "$LOG_FILE" 2>/dev/null || true
    DIAG_READY=1
  fi
  exec 6>&-
}

safe_remove() {
  [ ! -e "$1" ] && [ ! -L "$1" ] && return 0
  safe_regular_path "$1" || return 1
  /bin/rm -f "$1"
}

reset_main() {
  PID="" START="" MODE="off" END="" TIMEOUT="" DISPLAY="0" ARGV=""
  STATE_STATUS="none"
}

read_main() {
  local k v size
  reset_main
  [ -e "$STATE_FILE" ] || { [ ! -L "$STATE_FILE" ] && return 0; }
  safe_regular_path "$STATE_FILE" || { STATE_STATUS="invalid"; return 1; }
  size=$(/usr/bin/stat -f %z "$STATE_FILE" 2>/dev/null) || { STATE_STATUS="invalid"; return 1; }
  [ "$size" -le 2048 ] || { STATE_STATUS="invalid"; return 1; }
  while IFS='=' read -r k v; do
    case "$k" in
      PID) PID=$v ;; START) START=$v ;; MODE) MODE=$v ;; END) END=$v ;;
      TIMEOUT) TIMEOUT=$v ;; DISPLAY) DISPLAY=$v ;; ARGV) ARGV=$v ;;
    esac
  done <"$STATE_FILE"
  case "$PID" in ''|*[!0-9]*) STATE_STATUS="invalid"; return 1 ;; esac
  [ "${#PID}" -le 10 ] && [ "$PID" -gt 1 ] 2>/dev/null \
    && [ -n "$START" ] && [ "${#START}" -le 64 ] \
    || { STATE_STATUS="invalid"; return 1; }
  case "$MODE" in forever|hours|until) ;; *) STATE_STATUS="invalid"; return 1 ;; esac
  case "$DISPLAY" in 0|1) ;; *) STATE_STATUS="invalid"; return 1 ;; esac
  case "$END" in ''|*[!0-9]*) [ -z "$END" ] || { STATE_STATUS="invalid"; return 1; } ;; esac
  case "$TIMEOUT" in ''|*[!0-9]*) [ -z "$TIMEOUT" ] || { STATE_STATUS="invalid"; return 1; } ;; esac
  [ "${#END}" -le 12 ] && [ "${#TIMEOUT}" -le 10 ] \
    || { STATE_STATUS="invalid"; return 1; }
  if [ -z "$END" ]; then
    [ "$MODE" = "forever" ] && [ -z "$TIMEOUT" ] || { STATE_STATUS="invalid"; return 1; }
  else
    [ "$MODE" != "forever" ] && [ -n "$TIMEOUT" ] && [ "$TIMEOUT" -gt 0 ] 2>/dev/null \
      || { STATE_STATUS="invalid"; return 1; }
  fi
  [ "$ARGV" = "$(canonical_argv "$DISPLAY" "$TIMEOUT")" ] \
    || { STATE_STATUS="invalid"; return 1; }
  STATE_STATUS="valid"
}

main_content() {
  /usr/bin/printf 'PID=%s\nSTART=%s\nMODE=%s\nEND=%s\nTIMEOUT=%s\nDISPLAY=%s\nARGV=%s\n' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7"
}

commit_main() {
  atomic_write "$STATE_FILE" "$(main_content "$1" "$2" "$3" "$4" "$5" "$6" "$7")" \
    || return 1
  PID="$1" START="$2" MODE="$3" END="$4" TIMEOUT="$5" DISPLAY="$6" ARGV="$7"
  STATE_STATUS="valid"
  log_event state_commit "owner=$PID mode=$MODE display=$DISPLAY end=${END:-none}"
}

commit_off() {
  safe_remove "$STATE_FILE" \
    && safe_remove "$PENDING_FILE" || return 1
  reset_main
  log_event state_commit 'mode=off display=0'
}

canonical_argv() {
  local display="$1" timeout="${2:-}" flags="-i"
  [ "$display" = "1" ] && flags="-di"
  if [ -n "$timeout" ]; then
    /usr/bin/printf '/usr/bin/caffeinate %s -t %s' "$flags" "$timeout"
  else
    /usr/bin/printf '/usr/bin/caffeinate %s' "$flags"
  fi
}

# OBS_STATUS is exact, absent, mismatch, or indeterminate.
observe_process() {
  local wanted_pid="$1" wanted_start="$2" wanted_argv="$3"
  local tmp line opid dow mon day tm year command
  OBS_STATUS="indeterminate" OBS_START="" OBS_ARGV=""
  [ -n "$wanted_pid" ] || { OBS_STATUS="absent"; return 0; }

  tmp=$(/usr/bin/mktemp "$DATA_DIR/observe.XXXXXX") || return 1
  if [ "$TEST_MODE" -eq 1 ] && [ -n "$OBSERVER_BIN" ]; then
    if ! run_capture 1 "$tmp" "$OBSERVER_BIN" "$wanted_pid"; then
      /bin/rm -f "$tmp"
      return 1
    fi
    IFS='|' read -r OBS_STATUS OBS_START OBS_ARGV <"$tmp"
    /bin/rm -f "$tmp"
    case "$OBS_STATUS" in exact|absent|mismatch|indeterminate) return 0 ;; esac
    OBS_STATUS="indeterminate"
    return 1
  fi

  if ! run_capture 1 "$tmp" /usr/bin/env LC_ALL=C /bin/ps -ww -p "$wanted_pid" \
      -o pid= -o lstart= -o command=; then
    if /bin/kill -0 "$wanted_pid" 2>/dev/null; then
      OBS_STATUS="indeterminate"
    else
      OBS_STATUS="absent"
    fi
    /bin/rm -f "$tmp"
    return 0
  fi
  line=$(<"$tmp")
  /bin/rm -f "$tmp"
  [ -n "$line" ] || { OBS_STATUS="indeterminate"; return 0; }
  read -r opid dow mon day tm year command <<EOF
$line
EOF
  case "$opid" in ''|*[!0-9]*) OBS_STATUS="indeterminate"; return 0 ;; esac
  OBS_START="$dow $mon $day $tm $year"
  OBS_ARGV="$command"
  if [ "$opid" != "$wanted_pid" ] || [ "$OBS_START" != "$wanted_start" ] \
      || [ "$OBS_ARGV" != "$wanted_argv" ]; then
    OBS_STATUS="mismatch"
  else
    OBS_STATUS="exact"
  fi
}

stop_identity() {
  local pid="$1" start="$2" argv="$3" i
  observe_process "$pid" "$start" "$argv" || return 1
  case "$OBS_STATUS" in absent|mismatch) return 0 ;; exact) ;; *) return 1 ;; esac
  /bin/kill -TERM "$pid" 2>/dev/null || true
  i=0
  while [ "$i" -lt 20 ]; do
    observe_process "$pid" "$start" "$argv" || return 1
    case "$OBS_STATUS" in absent|mismatch) return 0 ;; exact) ;; *) return 1 ;; esac
    /bin/sleep 0.1
    i=$((i + 1))
  done
  observe_process "$pid" "$start" "$argv" || return 1
  [ "$OBS_STATUS" = "exact" ] || { [ "$OBS_STATUS" = "absent" ] || [ "$OBS_STATUS" = "mismatch" ]; return; }
  /bin/kill -KILL "$pid" 2>/dev/null || true
  i=0
  while [ "$i" -lt 10 ]; do
    observe_process "$pid" "$start" "$argv" || return 1
    case "$OBS_STATUS" in absent|mismatch) return 0 ;; exact) ;; *) return 1 ;; esac
    /bin/sleep 0.1
    i=$((i + 1))
  done
  return 1
}

normalize_start_identity() {
  local dow mon day clock year extra
  read -r dow mon day clock year extra <<EOF
$1
EOF
  [ -n "$dow" ] && [ -n "$mon" ] && [ -n "$day" ] \
    && [ -n "$clock" ] && [ -n "$year" ] && [ -z "$extra" ] || return 1
  /usr/bin/printf '%s %s %s %s %s\n' "$dow" "$mon" "$day" "$clock" "$year"
}

same_start_identity() {
  local first second
  [ "$1" = "$2" ] && return 0
  first=$(normalize_start_identity "$1") || return 1
  second=$(normalize_start_identity "$2") || return 1
  [ "$first" = "$second" ]
}

# Adopt the state format used before state moved out of Library/Caches. The
# legacy lock prevents racing an in-flight invocation of the old plugin.
migrate_legacy() {
  local pending_status="${1:-none}"
  local k v size legacy_pid="" legacy_end="" legacy_mode="" legacy_start=""
  local legacy_timeout="" legacy_argv="" legacy_semantic_valid=1
  local observed_start observed_argv
  [ ! -L "$LEGACY_DIR" ] || return 1
  mkdir -p "$LEGACY_DIR" || return 1
  [ -d "$LEGACY_DIR" ] && [ ! -L "$LEGACY_DIR" ] || return 1
  chmod 700 "$LEGACY_DIR" || return 1
  prepare_lock "$LEGACY_LOCK" || return 1
  exec 7>>"$LEGACY_LOCK" || return 1
  /usr/bin/lockf -s -t 2 7 || { exec 7>&-; return 1; }
  if [ ! -e "$LEGACY_STATE_FILE" ] && [ ! -L "$LEGACY_STATE_FILE" ]; then
    exec 7>&-
    return
  fi
  safe_regular_path "$LEGACY_STATE_FILE" || { exec 7>&-; return 1; }

  size=$(/usr/bin/stat -f %z "$LEGACY_STATE_FILE" 2>/dev/null) \
    || { exec 7>&-; return 1; }
  if [ "$size" -gt 512 ]; then
    exec 7>&-
    return 1
  fi
  while IFS='=' read -r k v; do
    case "$k" in
      PID) legacy_pid=$v ;; END) legacy_end=$v ;;
      MODE) legacy_mode=$v ;; START) legacy_start=$v ;;
    esac
  done <"$LEGACY_STATE_FILE"
  case "$legacy_pid" in ''|*[!0-9]*) exec 7>&-; return 1 ;; esac
  case "$legacy_end" in *[!0-9]*) legacy_semantic_valid=0; legacy_end="" ;; esac
  case "$legacy_mode" in
    ''|forever|hours|until) ;;
    *) legacy_semantic_valid=0; legacy_mode="" ;;
  esac
  if ! [ "$legacy_pid" -gt 1 ] 2>/dev/null \
      || [ "${#legacy_pid}" -gt 10 ] || [ -z "$legacy_start" ] \
      || [ "${#legacy_start}" -gt 64 ] || [ "${#legacy_end}" -gt 12 ]; then
    exec 7>&-
    return 1
  fi

  observe_process "$legacy_pid" "" "" || { exec 7>&-; return 1; }
  case "$OBS_STATUS" in
    absent) safe_remove "$LEGACY_STATE_FILE"; exec 7>&-; return ;;
    indeterminate) exec 7>&-; return 1 ;;
  esac
  observed_start=$OBS_START observed_argv=$OBS_ARGV
  if ! same_start_identity "$observed_start" "$legacy_start"; then
    safe_remove "$LEGACY_STATE_FILE"
    exec 7>&-
    return
  fi
  legacy_start=$observed_start
  if [ "$observed_argv" = "/usr/bin/caffeinate -i" ]; then
    legacy_timeout=""
    [ -z "$legacy_mode" ] && legacy_mode=forever
    [ -z "$legacy_end" ] && [ "$legacy_mode" = forever ] || legacy_semantic_valid=0
  elif [[ "$observed_argv" =~ ^/usr/bin/caffeinate\ -i\ -t\ ([1-9][0-9]{0,9})$ ]]; then
    legacy_timeout=${BASH_REMATCH[1]}
    [ -z "$legacy_mode" ] && legacy_mode=hours
    [ -n "$legacy_end" ] \
      && { [ "$legacy_mode" = hours ] || [ "$legacy_mode" = until ]; } \
      || legacy_semantic_valid=0
  else
    safe_remove "$LEGACY_STATE_FILE"
    exec 7>&-
    return
  fi
  legacy_argv=$observed_argv

  [ "$pending_status" != "invalid" ] || { exec 7>&-; return 1; }
  if [ "$pending_status" = "valid" ]; then
    if [ "$OLD_MODE" != "off" ] && [ "$OLD_PID" = "$legacy_pid" ] \
        && same_start_identity "$OLD_START" "$legacy_start" \
        && [ "$OLD_ARGV" = "$legacy_argv" ]; then
      safe_remove "$LEGACY_STATE_FILE" || { exec 7>&-; return 1; }
    else
      stop_identity "$legacy_pid" "$legacy_start" "$legacy_argv" \
        || { exec 7>&-; return 1; }
      safe_remove "$LEGACY_STATE_FILE" || { exec 7>&-; return 1; }
    fi
    exec 7>&-
    return
  fi

  read_main
  if [ "$STATE_STATUS" = "invalid" ]; then exec 7>&-; return 1; fi
  if [ "$STATE_STATUS" = "valid" ]; then
    if [ "$PID" != "$legacy_pid" ] || ! same_start_identity "$START" "$legacy_start" \
        || [ "$ARGV" != "$legacy_argv" ]; then
      stop_identity "$legacy_pid" "$legacy_start" "$legacy_argv" \
        || { exec 7>&-; return 1; }
    fi
    safe_remove "$LEGACY_STATE_FILE" || { exec 7>&-; return 1; }
    exec 7>&-
    return
  fi

  if [ "$legacy_semantic_valid" -ne 1 ]; then
    stop_identity "$legacy_pid" "$legacy_start" "$legacy_argv" \
      || { exec 7>&-; return 1; }
    safe_remove "$LEGACY_STATE_FILE" || { exec 7>&-; return 1; }
    exec 7>&-
    return
  fi

  commit_main "$legacy_pid" "$legacy_start" "$legacy_mode" "$legacy_end" \
    "$legacy_timeout" 0 "$legacy_argv" || { exec 7>&-; return 1; }
  safe_remove "$LEGACY_STATE_FILE" || { exec 7>&-; return 1; }
  exec 7>&-
}

reset_pending() {
  PHASE="" TXID="" OLD_PID="" OLD_START="" OLD_MODE="off" OLD_END=""
  OLD_TIMEOUT="" OLD_DISPLAY="0" OLD_ARGV="" TARGET_MODE="off"
  TARGET_END="" TARGET_DISPLAY="0" ATTEMPT="0" CAND_TOKEN="" CAND_PID="" CAND_START=""
  CAND_ARGV="" CAND_TIMEOUT="" RETRY_AT="0" RETRY_COUNT="0"
  PENDING_STATUS="none"
}

read_pending() {
  local k v size expected_display expected_argv
  reset_pending
  [ -e "$PENDING_FILE" ] || { [ ! -L "$PENDING_FILE" ] && return 0; }
  safe_regular_path "$PENDING_FILE" || { PENDING_STATUS="invalid"; return 1; }
  size=$(/usr/bin/stat -f %z "$PENDING_FILE" 2>/dev/null) || { PENDING_STATUS="invalid"; return 1; }
  [ "$size" -le 8192 ] || { PENDING_STATUS="invalid"; return 1; }
  while IFS='=' read -r k v; do
    case "$k" in
      PHASE) PHASE=$v ;; TXID) TXID=$v ;; OLD_PID) OLD_PID=$v ;;
      OLD_START) OLD_START=$v ;; OLD_MODE) OLD_MODE=$v ;; OLD_END) OLD_END=$v ;;
      OLD_TIMEOUT) OLD_TIMEOUT=$v ;; OLD_DISPLAY) OLD_DISPLAY=$v ;; OLD_ARGV) OLD_ARGV=$v ;;
      TARGET_MODE) TARGET_MODE=$v ;; TARGET_END) TARGET_END=$v ;;
      TARGET_DISPLAY) TARGET_DISPLAY=$v ;; ATTEMPT) ATTEMPT=$v ;;
      CAND_TOKEN) CAND_TOKEN=$v ;;
      CAND_PID) CAND_PID=$v ;;
      CAND_START) CAND_START=$v ;; CAND_ARGV) CAND_ARGV=$v ;;
      CAND_TIMEOUT) CAND_TIMEOUT=$v ;; RETRY_AT) RETRY_AT=$v ;; RETRY_COUNT) RETRY_COUNT=$v ;;
    esac
  done <"$PENDING_FILE"
  case "$PHASE" in
    PREPARED|STOPPING|TARGET_STARTING|TARGET_CANDIDATE|OLD_STOPPING|TARGET_CLEANUP) ;;
    *) PENDING_STATUS="invalid"; return 1 ;;
  esac
  [ -n "$TXID" ] && [ "${#TXID}" -le 96 ] || { PENDING_STATUS="invalid"; return 1; }
  case "$TXID" in *[!A-Za-z0-9._-]*|*..*) PENDING_STATUS="invalid"; return 1 ;; esac
  case "$OLD_MODE" in off|forever|hours|until) ;; *) PENDING_STATUS="invalid"; return 1 ;; esac
  case "$TARGET_MODE" in off|forever|hours|until) ;; *) PENDING_STATUS="invalid"; return 1 ;; esac
  case "$OLD_DISPLAY:$TARGET_DISPLAY" in 0:0|0:1|1:0|1:1) ;; *) PENDING_STATUS="invalid"; return 1 ;; esac
  case "$RETRY_AT" in ''|*[!0-9]*) PENDING_STATUS="invalid"; return 1 ;; esac
  case "$RETRY_COUNT" in ''|*[!0-9]*) PENDING_STATUS="invalid"; return 1 ;; esac
  case "$ATTEMPT" in ''|*[!0-9]*) PENDING_STATUS="invalid"; return 1 ;; esac
  [ "${#RETRY_AT}" -le 12 ] && [ "${#RETRY_COUNT}" -le 10 ] \
      && [ "${#ATTEMPT}" -le 10 ] \
    || { PENDING_STATUS="invalid"; return 1; }

  if [ "$OLD_MODE" = "off" ]; then
    [ -z "$OLD_PID$OLD_START$OLD_END$OLD_TIMEOUT$OLD_ARGV" ] \
      || { PENDING_STATUS="invalid"; return 1; }
  else
    case "$OLD_PID" in ''|*[!0-9]*) PENDING_STATUS="invalid"; return 1 ;; esac
    [ "$OLD_PID" -gt 1 ] 2>/dev/null && [ "${#OLD_PID}" -le 10 ] \
      && [ -n "$OLD_START" ] && [ "${#OLD_START}" -le 64 ] \
      || { PENDING_STATUS="invalid"; return 1; }
    if [ "$OLD_MODE" = "forever" ]; then
      [ -z "$OLD_END$OLD_TIMEOUT" ] || { PENDING_STATUS="invalid"; return 1; }
    else
      case "$OLD_END" in ''|*[!0-9]*) PENDING_STATUS="invalid"; return 1 ;; esac
      case "$OLD_TIMEOUT" in ''|*[!0-9]*) PENDING_STATUS="invalid"; return 1 ;; esac
      [ "${#OLD_END}" -le 12 ] && [ "${#OLD_TIMEOUT}" -le 10 ] \
        || { PENDING_STATUS="invalid"; return 1; }
      [ "$OLD_TIMEOUT" -gt 0 ] 2>/dev/null || { PENDING_STATUS="invalid"; return 1; }
    fi
    [ "$OLD_ARGV" = "$(canonical_argv "$OLD_DISPLAY" "$OLD_TIMEOUT")" ] \
      || { PENDING_STATUS="invalid"; return 1; }
  fi

  if [ "$TARGET_MODE" = "off" ]; then
    [ -z "$TARGET_END" ] && [ "$TARGET_DISPLAY" = 0 ] \
      || { PENDING_STATUS="invalid"; return 1; }
  elif [ "$TARGET_MODE" = "forever" ]; then
    [ -z "$TARGET_END" ] || { PENDING_STATUS="invalid"; return 1; }
  else
    case "$TARGET_END" in ''|*[!0-9]*) PENDING_STATUS="invalid"; return 1 ;; esac
    [ "${#TARGET_END}" -le 12 ] || { PENDING_STATUS="invalid"; return 1; }
  fi

  if [ -n "$CAND_PID" ]; then
    case "$CAND_PID" in *[!0-9]*) PENDING_STATUS="invalid"; return 1 ;; esac
    [ "$CAND_PID" -gt 1 ] 2>/dev/null && [ "${#CAND_PID}" -le 10 ] \
      || { PENDING_STATUS="invalid"; return 1; }
  fi
  case "$CAND_TIMEOUT" in ''|*[!0-9]*) [ -z "$CAND_TIMEOUT" ] \
      || { PENDING_STATUS="invalid"; return 1; } ;; esac
  [ "${#CAND_TIMEOUT}" -le 10 ] || { PENDING_STATUS="invalid"; return 1; }
  case "$PHASE" in
    TARGET_STARTING|TARGET_CANDIDATE|OLD_STOPPING|TARGET_CLEANUP)
      [ -n "$CAND_TOKEN" ] && [ "${#CAND_TOKEN}" -le 112 ] \
        || { PENDING_STATUS="invalid"; return 1; }
      case "$CAND_TOKEN" in *[!A-Za-z0-9._-]*|*..*) PENDING_STATUS="invalid"; return 1 ;; esac
      [ "$CAND_TOKEN" = "$TXID.$ATTEMPT.target" ] \
        || { PENDING_STATUS="invalid"; return 1; }
      expected_display=$TARGET_DISPLAY
      ;;
    *) [ -z "$CAND_TOKEN" ] || { PENDING_STATUS="invalid"; return 1; }; expected_display="" ;;
  esac
  if [ -n "$expected_display" ]; then
    expected_argv=$(canonical_argv "$expected_display" "$CAND_TIMEOUT")
    [ "$CAND_ARGV" = "$expected_argv" ] || { PENDING_STATUS="invalid"; return 1; }
  fi
  case "$PHASE" in
    TARGET_CANDIDATE|OLD_STOPPING|TARGET_CLEANUP)
      [ -n "$CAND_PID" ] && [ -n "$CAND_START" ] && [ "${#CAND_START}" -le 64 ] \
        || { PENDING_STATUS="invalid"; return 1; }
      ;;
    TARGET_STARTING)
      if [ -n "$CAND_PID" ]; then
        [ -n "$CAND_START" ] && [ "${#CAND_START}" -le 64 ] \
          || { PENDING_STATUS="invalid"; return 1; }
      else
        [ -z "$CAND_START" ] || { PENDING_STATUS="invalid"; return 1; }
      fi
      ;;
    *)
      [ -z "$CAND_PID$CAND_START$CAND_ARGV$CAND_TIMEOUT" ] \
        || { PENDING_STATUS="invalid"; return 1; }
      ;;
  esac
  PENDING_STATUS="valid"
}

pending_content() {
  /usr/bin/printf '%s\n' \
    "PHASE=$PHASE" "TXID=$TXID" "OLD_PID=$OLD_PID" "OLD_START=$OLD_START" \
    "OLD_MODE=$OLD_MODE" "OLD_END=$OLD_END" "OLD_TIMEOUT=$OLD_TIMEOUT" \
    "OLD_DISPLAY=$OLD_DISPLAY" "OLD_ARGV=$OLD_ARGV" "TARGET_MODE=$TARGET_MODE" \
    "TARGET_END=$TARGET_END" "TARGET_DISPLAY=$TARGET_DISPLAY" "ATTEMPT=$ATTEMPT" \
    "CAND_TOKEN=$CAND_TOKEN" \
    "CAND_PID=$CAND_PID" \
    "CAND_START=$CAND_START" "CAND_ARGV=$CAND_ARGV" "CAND_TIMEOUT=$CAND_TIMEOUT" \
    "RETRY_AT=$RETRY_AT" "RETRY_COUNT=$RETRY_COUNT"
}

write_pending() {
  atomic_write "$PENDING_FILE" "$(pending_content)"
}

test_killpoint() {
  if [ "$TEST_MODE" -eq 1 ] && [ "${CAFFEINATE_TEST_KILLPOINT:-}" = "$1" ]; then
    exit 99
  fi
}

set_phase() {
  PHASE="$1" RETRY_AT="0" RETRY_COUNT="0"
  write_pending || return 1
  log_event phase "txid=$TXID phase=$PHASE attempt=$ATTEMPT"
  test_killpoint "$PHASE"
}

backoff_pending() {
  local delay now
  case "$RETRY_COUNT" in 0) delay=30 ;; 1) delay=60 ;; 2) delay=120 ;; 3) delay=240 ;; *) delay=300 ;; esac
  now=$(now_epoch) || return 1
  RETRY_COUNT=$((RETRY_COUNT + 1))
  RETRY_AT=$((now + delay))
  write_pending || return 1
  log_event backoff "txid=$TXID phase=$PHASE retry=$RETRY_COUNT retry_at=$RETRY_AT"
}

new_txid() {
  /usr/bin/printf '%s.%s.%s' "$(now_epoch)" "$$" "$RANDOM"
}

candidate_wait_exec() {
  local token="$1" display="$2" timeout="${3:-}" i=0 control control_path
  control_path=$(candidate_control_path "$token") || return 1
  if [ "$TEST_MODE" -eq 1 ] && [ -n "${CAFFEINATE_TEST_CANDIDATE_DELAY:-}" ]; then
    /bin/sleep "$CAFFEINATE_TEST_CANDIDATE_DELAY"
  fi
  while [ "$i" -lt 200 ]; do
    if [ -f "$control_path" ] && [ ! -L "$control_path" ]; then
      control=$(<"$control_path")
      if [ "$control" = "CANCEL:$token" ]; then
        safe_remove "$control_path"
        return
      fi
      if [ "$control" = "GO:$token" ]; then
        safe_remove "$control_path" || return 1
        if [ "$display" = 1 ]; then
          if [ -n "$timeout" ]; then exec "$CAFFEINATE_BIN" -di -t "$timeout"
          else exec "$CAFFEINATE_BIN" -di
          fi
        else
          if [ -n "$timeout" ]; then exec "$CAFFEINATE_BIN" -i -t "$timeout"
          else exec "$CAFFEINATE_BIN" -i
          fi
        fi
        return 1
      fi
    fi
    /bin/sleep 0.01
    i=$((i + 1))
  done
  return 0
}

candidate_control_path() {
  case "$1" in ''|*[!A-Za-z0-9._-]*|*..*) return 1 ;; esac
  /usr/bin/printf '%s/caffeinate.candidate.%s.control\n' "$DATA_DIR" "$1"
}

await_candidate_exec() {
  local i=0
  while [ "$i" -lt 20 ]; do
    observe_process "$CAND_PID" "$CAND_START" "$CAND_ARGV" || return 1
    case "$OBS_STATUS" in
      exact) return 0 ;;
      absent) return 2 ;;
      mismatch) [ "$OBS_START" = "$CAND_START" ] || return 2 ;;
      *) return 1 ;;
    esac
    /bin/sleep 0.01
    i=$((i + 1))
  done
  return 1
}

spawn_candidate() {
  local mode="$1" end="$2" display="$3" now remaining="" expected pid rc control_path
  now=$(now_epoch) || return 1
  if [ -n "$end" ]; then
    remaining=$((end - now))
    [ "$remaining" -gt 0 ] || return 2
  fi
  expected=$(canonical_argv "$display" "$remaining")
  ATTEMPT=$((ATTEMPT + 1))
  CAND_TOKEN="$TXID.$ATTEMPT.target" CAND_PID="" CAND_START=""
  CAND_ARGV="$expected" CAND_TIMEOUT="$remaining"
  PHASE="TARGET_STARTING"
  control_path=$(candidate_control_path "$CAND_TOKEN") || return 1
  safe_remove "$control_path" || return 1
  write_pending || return 1
  log_event phase "txid=$TXID phase=$PHASE attempt=$ATTEMPT"
  test_killpoint "$PHASE"

  candidate_wait_exec "$CAND_TOKEN" "$display" "$remaining" \
    </dev/null >/dev/null 2>&1 7>&- 8>&- 9>&- &
  pid=$!
  disown "$pid" 2>/dev/null || true
  test_killpoint TARGET_FORKED
  observe_process "$pid" "" "" || return 1
  [ -n "$OBS_START" ] || return 1
  CAND_PID="$pid" CAND_START="$OBS_START"
  write_pending || return 1
  test_killpoint TARGET_CLAIMED
  atomic_write "$control_path" "GO:$CAND_TOKEN" || return 1
  /bin/sleep 0.01
  await_candidate_exec
  rc=$?
  case "$rc" in 0) ;; 2) return 3 ;; *) return 1 ;; esac
  PHASE="TARGET_CANDIDATE"
  write_pending || return 1
  log_event phase "txid=$TXID phase=$PHASE attempt=$ATTEMPT"
  test_killpoint "$PHASE"
}

resume_starting() {
  local rc control_path i
  control_path=$(candidate_control_path "$CAND_TOKEN") || return 1
  if [ -z "$CAND_PID" ]; then
    atomic_write "$control_path" "CANCEL:$CAND_TOKEN" || return 1
    i=0
    while [ -e "$control_path" ] && [ "$i" -lt 50 ]; do
      /bin/sleep 0.05
      i=$((i + 1))
    done
    safe_remove "$control_path" || return 1
    CAND_TOKEN="" CAND_PID="" CAND_START="" CAND_ARGV="" CAND_TIMEOUT=""
    set_phase PREPARED
    return
  fi

  atomic_write "$control_path" "GO:$CAND_TOKEN" || return 1
  await_candidate_exec
  rc=$?
  case "$rc" in
    0)
      set_phase TARGET_CANDIDATE
      ;;
    2)
      safe_remove "$control_path" || return 1
      CAND_TOKEN="" CAND_PID="" CAND_START="" CAND_ARGV="" CAND_TIMEOUT=""
      set_phase PREPARED
      ;;
    *) backoff_pending; return 1 ;;
  esac
}

pending_candidate_exact() {
  [ -n "$CAND_PID" ] && [ -n "$CAND_START" ] || return 1
  observe_process "$CAND_PID" "$CAND_START" "$CAND_ARGV" || return 1
  case "$OBS_STATUS" in exact) return 0 ;; absent|mismatch) return 2 ;; *) return 1 ;; esac
}

cleanup_candidate_to_main() {
  local control_path
  [ "$PHASE" = "TARGET_CLEANUP" ] || set_phase TARGET_CLEANUP || return 1
  if [ -n "$CAND_PID" ] && [ -n "$CAND_START" ]; then
    stop_identity "$CAND_PID" "$CAND_START" "$CAND_ARGV" || { backoff_pending; return 1; }
  fi
  control_path=$(candidate_control_path "$CAND_TOKEN") || return 1
  safe_remove "$control_path" && safe_remove "$PENDING_FILE" || return 1
  normalize_main
}

commit_candidate() {
  local mode="$1" end="$2" display="$3" now rc control_path
  now=$(now_epoch) || return 1
  [ -z "$end" ] || [ "$end" -gt "$now" ] || return 2
  pending_candidate_exact
  rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  commit_main "$CAND_PID" "$CAND_START" "$mode" "$end" "$CAND_TIMEOUT" "$display" "$CAND_ARGV" \
    || return 1
  test_killpoint COMMITTED
  control_path=$(candidate_control_path "$CAND_TOKEN") || return 1
  safe_remove "$control_path" && safe_remove "$PENDING_FILE"
}

reconcile_pending() {
  local now rc
  read_pending || return 1
  [ "$PENDING_STATUS" = "valid" ] || return 0
  now=$(now_epoch) || return 1
  [ "$RETRY_AT" -le "$now" ] || return 2

  case "$PHASE" in
    PREPARED)
      if [ "$TARGET_MODE" = "off" ] \
          || { [ -n "$TARGET_END" ] && [ "$TARGET_END" -le "$now" ]; }; then
        set_phase STOPPING || return 1
      else
        spawn_candidate "$TARGET_MODE" "$TARGET_END" "$TARGET_DISPLAY"
        rc=$?
        if [ "$rc" -eq 2 ]; then set_phase STOPPING || return 1
        elif [ "$rc" -eq 3 ]; then cleanup_candidate_to_main || return 1; return 1
        elif [ "$rc" -ne 0 ]; then return 1
        fi
      fi
      ;;
  esac

  case "$PHASE" in
    STOPPING)
      if [ "$OLD_MODE" != "off" ]; then
        stop_identity "$OLD_PID" "$OLD_START" "$OLD_ARGV" \
          || { backoff_pending; return 1; }
      fi
      commit_off
      return
      ;;
    TARGET_STARTING)
      resume_starting
      rc=$?
      case "$rc" in 0) ;; 2) return 0 ;; *) return 1 ;; esac
      ;;
  esac

  case "$PHASE" in
    TARGET_CANDIDATE)
      now=$(now_epoch) || return 1
      if [ -n "$TARGET_END" ] && [ "$TARGET_END" -le "$now" ]; then
        cleanup_candidate_to_main
        return
      fi
      set_phase OLD_STOPPING || return 1
      ;;
    TARGET_CLEANUP) cleanup_candidate_to_main; return ;;
  esac

  case "$PHASE" in
    OLD_STOPPING)
      now=$(now_epoch) || return 1
      if [ -n "$TARGET_END" ] && [ "$TARGET_END" -le "$now" ]; then
        cleanup_candidate_to_main
        return
      fi
      if [ "$OLD_MODE" != "off" ]; then
        pending_candidate_exact
        rc=$?
        if [ "$rc" -eq 2 ]; then cleanup_candidate_to_main; return 1
        elif [ "$rc" -ne 0 ]; then backoff_pending; return 1
        fi
        stop_identity "$OLD_PID" "$OLD_START" "$OLD_ARGV" \
          || { backoff_pending; return 1; }
      fi
      commit_candidate "$TARGET_MODE" "$TARGET_END" "$TARGET_DISPLAY"
      rc=$?
      case "$rc" in
        0) return 0 ;;
        2) cleanup_candidate_to_main || return 1; return 1 ;;
        *) backoff_pending; return 1 ;;
      esac
      ;;
  esac
}

normalize_main() {
  local now
  if ! migrate_legacy "${PENDING_STATUS:-none}"; then
    log_event error 'category=migration'
    return 1
  fi
  read_main || return 1
  [ "$STATE_STATUS" = "valid" ] || return 0
  observe_process "$PID" "$START" "$ARGV" || return 1
  case "$OBS_STATUS" in
    absent|mismatch) safe_remove "$STATE_FILE"; reset_main; return ;;
    indeterminate) return 1 ;;
  esac
  if [ -n "$END" ]; then
    now=$(now_epoch) || return 1
    if [ "$END" -le "$now" ]; then
      stop_identity "$PID" "$START" "$ARGV" || return 1
      safe_remove "$STATE_FILE"
      reset_main
    fi
  fi
  return 0
}

prepare_transaction() {
  local target_mode="$1" target_end="$2" target_display="$3"
  # Reconciliation can remove a pending file while its parsed status remains
  # in memory. Refresh only the journal; reuse the main snapshot already
  # normalized under OWNER_LOCK so process observation is not repeated.
  read_pending || return 1
  [ "$PENDING_STATUS" = "none" ] || return 2

  TXID=$(new_txid) PHASE="PREPARED"
  OLD_PID="$PID" OLD_START="$START" OLD_MODE="$MODE" OLD_END="$END"
  OLD_TIMEOUT="$TIMEOUT" OLD_DISPLAY="$DISPLAY" OLD_ARGV="$ARGV"
  TARGET_MODE="$target_mode" TARGET_END="$target_end" TARGET_DISPLAY="$target_display"
  ATTEMPT="0" CAND_TOKEN="" CAND_PID="" CAND_START="" CAND_ARGV="" CAND_TIMEOUT=""
  RETRY_AT="0" RETRY_COUNT="0"
  write_pending || return 1
  log_event transaction_prepared \
    "txid=$TXID old=$OLD_MODE target=$TARGET_MODE display=$TARGET_DISPLAY end=${TARGET_END:-none}"
  test_killpoint PREPARED
  reconcile_pending
}

normalize_then_mutate() {
  local action="$1" arg1="${2:-}" now end display mode
  read_pending || return 1
  if [ "$PENDING_STATUS" = "valid" ]; then
    reconcile_pending || return 2
  elif [ "$PENDING_STATUS" != "none" ]; then
    return 1
  fi
  normalize_main || return 2

  case "$action" in
    c-toggle)
      if [ "$STATE_STATUS" = "valid" ]; then
        prepare_transaction off "" 0
      else
        prepare_transaction forever "" 0
      fi
      ;;
    display-toggle)
      if [ "$STATE_STATUS" = "valid" ]; then
        if [ "$DISPLAY" = "1" ]; then display=0; else display=1; fi
        prepare_transaction "$MODE" "$END" "$display"
      else
        prepare_transaction forever "" 1
      fi
      ;;
    stop) prepare_transaction off "" 0 ;;
    forever)
      if [ "$STATE_STATUS" = "valid" ]; then display="$DISPLAY"; else display=0; fi
      prepare_transaction forever "" "$display"
      ;;
    finite)
      mode="$arg1" end="$3"
      if [ "$STATE_STATUS" = "valid" ]; then display="$DISPLAY"; else display=0; fi
      prepare_transaction "$mode" "$end" "$display"
      ;;
    *) return 64 ;;
  esac
}

acquire_owner() {
  local wait="$1"
  exec 8>>"$OWNER_LOCK" || return 1
  /usr/bin/lockf -s -t "$wait" 8 || { exec 8>&-; return 1; }
}

release_owner() { exec 8>&-; }

format_remaining() {
  local secs="$1" h m
  if [ "$secs" -lt 60 ]; then /usr/bin/printf '%ds' "$secs"; return; fi
  h=$((secs / 3600)); m=$(((secs % 3600 + 59) / 60))
  if [ "$m" -ge 60 ]; then h=$((h + 1)); m=0; fi
  if [ "$h" -gt 0 ]; then
    if [ "$m" -gt 0 ]; then /usr/bin/printf '%dh%dm' "$h" "$m"; else /usr/bin/printf '%dh' "$h"; fi
  else
    /usr/bin/printf '%dm' "$m"
  fi
}

apply_ui() {
  local trusted="${1:-0}" trusted_pid="${2:-}" trusted_start="${3:-}" trusted_argv="${4:-}"
  local forced_invalid="${5:-0}" now remaining prefix apple_color
  exec 9>>"$UI_LOCK" || return 1
  /usr/bin/lockf -s -t 2 9 || { exec 9>&-; return 1; }
  acquire_owner 0 || { exec 9>&-; return 1; }
  read_pending || true
  read_main || true
  if [ "$forced_invalid" = 1 ] || [ "$PENDING_STATUS" = "invalid" ] \
      || [ "$STATE_STATUS" = "invalid" ]; then
    release_owner
    run_bounded 2 "$SKETCHYBAR_BIN" --set caffeinate label="狀態異常" \
      label.color="$RED_SOFT" label.padding_right="$PAD_WIDE" padding_right="$PAD_ITEM" \
      label.y_offset=1 update_freq=30 --set caffeinate.suffix label.drawing=off drawing=off \
      --set apple.logo icon.color="$RED_SOFT"
    exec 9>&-
    return
  fi
  if [ "$STATE_STATUS" != "valid" ]; then
    release_owner
    run_bounded 2 "$SKETCHYBAR_BIN" --set caffeinate label="$IDLE_LABEL" \
      label.color="$WHITE" label.padding_right="$PAD_WIDE" padding_right="$PAD_ITEM" \
      label.y_offset=1 update_freq=30 --set caffeinate.suffix label.drawing=off drawing=off \
      --set apple.logo icon.color="$WHITE"
    exec 9>&-
    return
  fi
  if [ "$trusted" != 1 ] || [ "$PID" != "$trusted_pid" ] \
      || [ "$START" != "$trusted_start" ] || [ "$ARGV" != "$trusted_argv" ]; then
    observe_process "$PID" "$START" "$ARGV" || { release_owner; exec 9>&-; return 1; }
    [ "$OBS_STATUS" = "exact" ] || { release_owner; exec 9>&-; return 1; }
  fi
  now=$(now_epoch) || { release_owner; exec 9>&-; return 1; }
  if [ -n "$END" ] && [ "$END" -le "$now" ]; then
    release_owner; exec 9>&-; return 1
  fi
  if [ "$DISPLAY" = "1" ]; then apple_color="$ORANGE_SOFT"; else apple_color="$WHITE"; fi
  if [ "$MODE" = "forever" ]; then
    release_owner
    run_bounded 2 "$SKETCHYBAR_BIN" --set caffeinate label="$FOREVER_LABEL" \
      label.color="$ORANGE_SOFT" label.padding_right="$PAD" padding_right=0 label.y_offset=1 \
      update_freq=30 --set caffeinate.suffix label="$CAFFEINATE_FOREVER" \
      label.color="$ORANGE_HARD" label.drawing=on drawing=on \
      --set apple.logo icon.color="$apple_color"
  else
    remaining=$((END - now)); prefix="$HOURS_LABEL"
    [ "$MODE" = "until" ] && prefix="$UNTIL_LABEL"
    release_owner
    run_bounded 2 "$SKETCHYBAR_BIN" --set caffeinate label="$prefix" \
      label.color="$YELLOW_SOFT" label.padding_right="$PAD" padding_right=0 label.y_offset=1 \
      update_freq=30 --set caffeinate.suffix label="$(format_remaining "$remaining")" \
      label.color="$YELLOW_HARD" label.drawing=on drawing=on \
      --set apple.logo icon.color="$apple_color"
  fi
  exec 9>&-
}

launch_recovery() {
  if [ "$TEST_MODE" -eq 1 ]; then
    /usr/bin/lockf -k -t 0 "$RECOVERY_LOCK" /usr/bin/env \
      CAFFEINATE_TEST_ROOT="$CAFFEINATE_TEST_ROOT" \
      CAFFEINATE_TEST_CAFFEINATE="$CAFFEINATE_BIN" \
      CAFFEINATE_TEST_SKETCHYBAR="$SKETCHYBAR_BIN" \
      CAFFEINATE_TEST_PMSET="$PMSET_BIN" \
      CAFFEINATE_TEST_OSASCRIPT="$OSASCRIPT_BIN" \
      CAFFEINATE_TEST_OBSERVER="$OBSERVER_BIN" \
      CAFFEINATE_TEST_NOW="$NOW_BIN" CONFIG_DIR="$CONFIG_DIR" \
      "$SCRIPT_PATH" __test__ __recover__ </dev/null >/dev/null 2>&1 &
  else
    /usr/bin/lockf -k -t 0 "$RECOVERY_LOCK" "$SCRIPT_PATH" __recover__ \
      </dev/null >/dev/null 2>&1 &
  fi
}

render() {
  local now needs_recovery=0 recovery_reason=""
  acquire_owner 0 || return 0
  read_pending
  if ! migrate_legacy "$PENDING_STATUS"; then
    log_event error 'category=migration'
    release_owner
    apply_ui 0 "" "" "" 1 || true
    return 1
  fi
  if [ "$PENDING_STATUS" = "valid" ]; then
    now=$(now_epoch 2>/dev/null || /bin/date +%s)
    if [ "$RETRY_AT" -le "$now" ]; then
      needs_recovery=1
      recovery_reason=pending_due
    fi
  fi
  read_main
  if [ "$STATE_STATUS" = "valid" ]; then
    observe_process "$PID" "$START" "$ARGV"
    case "$OBS_STATUS" in
      absent)
        needs_recovery=1
        recovery_reason=owner_absent
        ;;
      mismatch)
        needs_recovery=1
        recovery_reason=owner_mismatch
        ;;
      exact)
        if [ -n "$END" ]; then
          now=$(now_epoch 2>/dev/null || /bin/date +%s)
          if [ "$END" -le "$now" ]; then
            needs_recovery=1
            recovery_reason=deadline
          fi
        fi
        ;;
    esac
  fi
  release_owner
  if [ "$needs_recovery" -ne 0 ]; then
    log_event recovery_scheduled "reason=$recovery_reason"
    launch_recovery
  fi
  apply_ui || true
}

recover() {
  local i=0 now pending_log state_log
  acquire_owner 2 || return 1
  read_pending
  pending_log="$PENDING_STATUS phase=none"
  [ "$PENDING_STATUS" != "valid" ] || pending_log="valid phase=$PHASE"
  log_event recovery_begin "pending=$pending_log"
  if [ "$PENDING_STATUS" = "valid" ]; then
    while [ "$i" -lt 4 ]; do
      reconcile_pending || break
      read_pending
      [ "$PENDING_STATUS" = "valid" ] || break
      now=$(now_epoch 2>/dev/null || /bin/date +%s)
      [ "$RETRY_AT" -le "$now" ] || break
      i=$((i + 1))
    done
  else
    normalize_main || true
  fi
  read_pending || true
  read_main || true
  pending_log="$PENDING_STATUS phase=none"
  [ "$PENDING_STATUS" != "valid" ] || pending_log="valid phase=$PHASE"
  state_log="$STATE_STATUS"
  [ "$STATE_STATUS" != "valid" ] || state_log="valid mode=$MODE display=$DISPLAY"
  log_event recovery_end "pending=$pending_log state=$state_log"
  release_owner
  apply_ui || true
}

notify_error() {
  local category="$1" message="$2" now bucket token f suffix
  mkdir -p "$NOTICE_DIR" || return 0
  chmod 700 "$NOTICE_DIR" || return 0
  now=$(now_epoch 2>/dev/null || /bin/date +%s)
  log_event error "category=$category"
  bucket=$((now / 30))
  token="$NOTICE_DIR/${category}.${bucket}"
  ( set -o noclobber; : >"$token" ) 2>/dev/null || return 0
  chmod 600 "$token" 2>/dev/null || true
  for f in "$NOTICE_DIR/$category".*; do
    [ -f "$f" ] || continue
    suffix=${f##*.}
    [ "$suffix" -ge "$((bucket - 8))" ] 2>/dev/null || /bin/rm -f "$f"
  done
  run_bounded 2 "$OSASCRIPT_BIN" -e \
    "display notification \"$message\" with title \"Caffeinate\"" >/dev/null 2>&1 || true
}

run_mutation() {
  local action="$1" arg1="${2:-}" arg2="${3:-}" rc ui_pid ui_start ui_argv
  local pending_log state_log
  if ! acquire_owner 2; then notify_error lock "操作繁忙，请稍后重试"; return 1; fi
  log_event mutation_begin "action=$action"
  normalize_then_mutate "$action" "$arg1" "$arg2"
  rc=$?
  ui_pid="${PID:-}" ui_start="${START:-}" ui_argv="${ARGV:-}"
  read_pending || true
  read_main || true
  pending_log="$PENDING_STATUS phase=none"
  [ "$PENDING_STATUS" != "valid" ] || pending_log="valid phase=$PHASE"
  state_log="$STATE_STATUS"
  [ "$STATE_STATUS" != "valid" ] || state_log="valid mode=$MODE display=$DISPLAY"
  log_event mutation_end "action=$action rc=$rc pending=$pending_log state=$state_log"
  release_owner
  if [ "$rc" -ne 0 ]; then
    notify_error state "无法安全更新常亮状态"
    return "$rc"
  fi
  apply_ui 1 "$ui_pid" "$ui_start" "$ui_argv" || true
}

duration_arg() {
  local value="$1" max="$2" multiplier="$3"
  [[ "$value" =~ ^[1-9][0-9]{0,4}$ ]] || return 1
  value=$((10#$value))
  [ "$value" -le "$max" ] || return 1
  /usr/bin/printf '%s\n' "$((value * multiplier))"
}

parse_duration() {
  local input="$1" secs=0
  input="${input// /}"; input=$(/usr/bin/printf '%s' "$input" | /usr/bin/tr '[:upper:]' '[:lower:]')
  [ "${#input}" -le 10 ] || return 1
  if [[ "$input" =~ ^([0-9]+)h([0-9]+)m?$ ]]; then
    secs=$((10#${BASH_REMATCH[1]} * 3600 + 10#${BASH_REMATCH[2]} * 60))
  elif [[ "$input" =~ ^([0-9]+)h$ ]]; then secs=$((10#${BASH_REMATCH[1]} * 3600))
  elif [[ "$input" =~ ^([0-9]+)m$ ]]; then secs=$((10#${BASH_REMATCH[1]} * 60))
  elif [[ "$input" =~ ^[0-9]+$ ]]; then secs=$((10#$input * 60))
  else return 1; fi
  [ "$secs" -gt 0 ] && [ "$secs" -le 604800 ] || return 1
  /usr/bin/printf '%s\n' "$secs"
}

# Resolve a local wall time without relying on BSD date's arbitrary choice in
# a DST fold. A spring-gap time has no round-tripping candidate and is rejected.
resolve_wall_target() {
  local date_part="$1" hhmm="$2" threshold="$3" base candidate formatted best="" delta
  base=$(/bin/date -j -f '%Y-%m-%d %H:%M' "$date_part $hhmm" +%s 2>/dev/null) || return 1
  for delta in -7200 -3600 -1800 0 1800 3600 7200; do
    candidate=$((base + delta))
    formatted=$(/bin/date -r "$candidate" '+%Y-%m-%d %H:%M') || continue
    [ "$formatted" = "$date_part $hhmm" ] || continue
    [ "$candidate" -gt "$threshold" ] || continue
    if [ -z "$best" ] || [ "$candidate" -lt "$best" ]; then best=$candidate; fi
  done
  [ -n "$best" ] || return 1
  /usr/bin/printf '%s\n' "$best"
}

calendar_target() {
  local arg="$1" hhmm date_part today target now threshold
  now=$(now_epoch) || return 1
  if [[ "$arg" = +1d:* ]]; then
    hhmm=${arg#+1d:}
    date_part=$(/bin/date -v+1d +%Y-%m-%d) || return 1
    threshold=$((now - 1))
  else
    hhmm=$arg; today=$(/bin/date +%Y-%m-%d) || return 1
    # An invalid wall time today (the spring-forward gap) is rejected rather
    # than silently normalized or moved to tomorrow.
    resolve_wall_target "$today" "$hhmm" -1 >/dev/null || return 1
    if target=$(resolve_wall_target "$today" "$hhmm" "$now"); then
      /usr/bin/printf '%s\n' "$target"
      return
    fi
    date_part=$(/bin/date -v+1d +%Y-%m-%d) || return 1
    threshold=$((now - 1))
  fi
  resolve_wall_target "$date_part" "$hhmm" "$threshold"
}

custom() {
  local input secs end
  input=$("$OSASCRIPT_BIN" <<'OSA' 2>/dev/null
try
  set d to display dialog "保持唤醒多久？" & return & "格式：60 (分钟) / 1h / 1h30m / 90m" default answer "60" with title "Caffeinate"
  return text returned of d
on error
  return ""
end try
OSA
  )
  [ -n "$input" ] || return 0
  secs=$(parse_duration "$input") || { notify_error input "无法识别时长"; return 64; }
  end=$(($(now_epoch) + secs))
  run_mutation finite hours "$end"
}

display_sleep() {
  local rc=0 pending_log state_log
  acquire_owner 2 || { notify_error lock "操作繁忙，请稍后重试"; return 1; }
  log_event mutation_begin 'action=display-sleep'
  read_pending
  if [ "$PENDING_STATUS" = "valid" ]; then reconcile_pending || rc=1; fi
  if [ "$rc" -eq 0 ]; then
    normalize_main || rc=1
    read_main || rc=1
  fi
  if [ "$rc" -eq 0 ] && [ "$STATE_STATUS" = "valid" ] && [ "$DISPLAY" = "1" ]; then
    prepare_transaction "$MODE" "$END" 0 || rc=1
  fi
  if [ "$rc" -eq 0 ]; then
    run_bounded 5 "$PMSET_BIN" displaysleepnow || rc=3
  fi
  read_pending || true
  read_main || true
  pending_log="$PENDING_STATUS phase=none"
  [ "$PENDING_STATUS" != "valid" ] || pending_log="valid phase=$PHASE"
  state_log="$STATE_STATUS"
  [ "$STATE_STATUS" != "valid" ] || state_log="valid mode=$MODE display=$DISPLAY"
  log_event mutation_end "action=display-sleep rc=$rc pending=$pending_log state=$state_log"
  release_owner
  apply_ui || true
  run_bounded 2 "$SKETCHYBAR_BIN" --set apple.logo popup.drawing=off >/dev/null 2>&1 || true
  case "$rc" in 0) return 0 ;; 3) notify_error pmset "无法关闭显示器" ;; *) notify_error state "无法安全关闭屏幕常亮" ;; esac
  return 1
}

click() {
  case "${BUTTON:-}" in
    left) run_mutation c-toggle ;;
    right) run_bounded 2 "$SKETCHYBAR_BIN" --set caffeinate popup.drawing=toggle ;;
    '') return 0 ;;
    *) return 0 ;;
  esac
}

case "${1:-render}" in
  render) render ;;
  click) click ;;
  toggle) run_mutation c-toggle ;;
  display-toggle) run_mutation display-toggle ;;
  display-sleep) display_sleep ;;
  stop) run_mutation stop ;;
  forever) run_mutation forever ;;
  hours)
    seconds=$(duration_arg "${2:-1}" 168 3600) || exit 64
    run_mutation finite hours "$(($(now_epoch) + seconds))"
    ;;
  minutes)
    seconds=$(duration_arg "${2:-30}" 10080 60) || exit 64
    run_mutation finite hours "$(($(now_epoch) + seconds))"
    ;;
  until)
    target=$(calendar_target "${2:-}") || { notify_error input "无法识别目标时间"; exit 64; }
    run_mutation finite until "$target"
    ;;
  custom) custom ;;
  __recover__) recover ;;
  __resolve-wall)
    [ "$TEST_MODE" -eq 1 ] || exit 0
    resolve_wall_target "${2:-}" "${3:-}" "${4:-0}"
    ;;
  __log__)
    [ "$TEST_MODE" -eq 1 ] || exit 0
    log_count="${2:-1}"
    case "$log_count" in ''|*[!0-9]*) exit 64 ;; esac
    [ "$log_count" -le 100 ] 2>/dev/null || exit 64
    while [ "$log_count" -gt 0 ]; do
      log_event fixture 'key=value'
      log_count=$((log_count - 1))
    done
    ;;
  __log_delayed__)
    [ "$TEST_MODE" -eq 1 ] || exit 0
    log_event fixture 'step=before'
    /bin/sleep 1.1
    log_event fixture 'step=after'
    ;;
  *) exit 0 ;;
esac
