#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
CONFIG_ROOT="${SCRIPT_DIR%/helper}"
# shellcheck source=runtime.sh
source "$SCRIPT_DIR/runtime.sh"

SERVICE=homebrew.mxcl.sketchybar
BOOTSTRAP=git.felix.helper
TARGET="$SCRIPT_DIR/helper"
WORK_DIR=
STAGING_FILE=
PUBLISHED=false
RESTART_REQUESTED=false
FINALIZED=false
ROLLBACK_RUNNING=false
ROLLBACK_DONE=false
ROLLBACK_DEGRADED=false
HOTLOAD_DISABLED=false
MARKER_OWNED=false
PRESERVE_WORK=false
INTERRUPTED=false
ORIGINAL_STATE_PRESENT=false
ORIGINAL_CIRCUIT_OPEN=false
preflight_pid=
preflight_identity=

helper_runtime_init || exit 1

helper_signal() {
  INTERRUPTED=true
  helper_log "level=warning event=install-interrupted signal=pending phase=${PHASE:-initializing}"
}

stop_preflight() {
  local current_identity
  [ -n "${preflight_pid:-}" ] || return 0

  kill -TERM "$preflight_pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$preflight_pid" 2>/dev/null || break
    sleep 0.1 8>&-
  done
  if kill -0 "$preflight_pid" 2>/dev/null; then
    current_identity="$(helper_process_identity "$preflight_pid" 2>/dev/null || true)"
    if [ -n "$preflight_identity" ] && [ "$current_identity" = "$preflight_identity" ]; then
      kill -KILL "$preflight_pid" 2>/dev/null || true
    fi
  fi
  wait "$preflight_pid" 2>/dev/null || true
  preflight_pid=
}

marker_is_owned() {
  local pid identity nonce deadline extra
  [ -f "$HELPER_RUNTIME_DIR/install-in-progress" ] \
    && [ ! -L "$HELPER_RUNTIME_DIR/install-in-progress" ] || return 1
  read -r pid identity nonce deadline extra < "$HELPER_RUNTIME_DIR/install-in-progress" || return 1
  [ -z "${extra:-}" ] \
    && [ "$pid" = "$$" ] \
    && [ "$identity" = "$installer_identity" ] \
    && [ "$nonce" = "$transaction_nonce" ]
}

recovery_lock() {
  exec 7>"$HELPER_RUNTIME_DIR/recovery.lock" || return 1
  if ! /usr/bin/lockf -s -t 10 7; then
    helper_log "level=error event=recovery-lock-timeout phase=${PHASE:-unknown}"
    exec 7>&-
    return 1
  fi
}

recovery_unlock() {
  exec 7>&-
}

enable_hotload() {
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if sketchybar --hotload on 7>&- 8>&-; then
      HOTLOAD_DISABLED=false
      return 0
    fi
    sleep 0.2 7>&- 8>&-
  done
  helper_log "level=error event=install-finalization-failed phase=hotload-on"
  return 1
}

restore_recovery_state() {
  local state="$HELPER_RUNTIME_DIR/recovery.state"
  local staging="$HELPER_RUNTIME_DIR/.recovery.rollback.$transaction_nonce"

  if $ORIGINAL_STATE_PRESENT; then
    cp "$original_state" "$staging" 7>&- 8>&- \
      && chmod 600 "$staging" 7>&- 8>&- \
      && mv -f "$staging" "$state" 7>&- 8>&- \
      && [ "$(shasum -a 256 "$state" 7>&- 8>&- | awk '{print $1}' 7>&- 8>&-)" = "$original_state_hash" ] \
      && return 0
  else
    rm -f "$state" 7>&- 8>&- && [ ! -e "$state" ] && return 0
  fi

  rm -f "$staging" 7>&- 8>&-
  helper_log "level=error event=rollback-phase-failed phase=recovery-state"
  if helper_state_write open 2; then
    helper_log "level=warning event=rollback-fail-closed state=open failures=2"
    ROLLBACK_DEGRADED=true
    PRESERVE_WORK=true
    return 0
  else
    helper_log "level=error event=rollback-fail-closed-write-failed"
  fi
  return 1
}

rollback_transaction() {
  local restart="${1:?restart flag required}"
  local rollback_rc=0 ks_rc=0
  local rollback_before_runs= rollback_before_pid=

  $ROLLBACK_RUNNING && return 1
  ROLLBACK_RUNNING=true
  PHASE=rollback

  if ! recovery_lock; then
    PRESERVE_WORK=true
    ROLLBACK_RUNNING=false
    return 1
  fi
  if ! sketchybar --hotload off 7>&- 8>&-; then
    helper_log "level=error event=rollback-phase-failed phase=hotload-off"
    recovery_unlock
    PRESERVE_WORK=true
    ROLLBACK_RUNNING=false
    return 1
  fi
  HOTLOAD_DISABLED=true

  if [ "$had_binary" = yes ]; then
    STAGING_FILE="$SCRIPT_DIR/.helper.rollback.$transaction_nonce"
    if ! cp "$backup" "$STAGING_FILE" 7>&- 8>&- \
      || ! chmod 700 "$STAGING_FILE" 7>&- 8>&- \
      || ! /bin/sync 7>&- 8>&- \
      || ! mv -f "$STAGING_FILE" "$TARGET" 7>&- 8>&- \
      || [ "$(shasum -a 256 "$TARGET" 7>&- 8>&- | awk '{print $1}' 7>&- 8>&-)" != "$backup_hash" ]; then
      helper_log "level=error event=rollback-phase-failed phase=binary"
      rollback_rc=1
    else
      STAGING_FILE=
    fi
  elif ! rm -f "$TARGET" 7>&- 8>&- || [ -e "$TARGET" ]; then
    helper_log "level=error event=rollback-phase-failed phase=fresh-binary-remove"
    rollback_rc=1
  fi

  restore_recovery_state || rollback_rc=1

  if marker_is_owned; then
    rm -f "$HELPER_RUNTIME_DIR/install-in-progress" 7>&- 8>&- || rollback_rc=1
  else
    helper_log "level=error event=rollback-phase-failed phase=marker-ownership"
    rollback_rc=1
  fi

  if [ "$rollback_rc" -eq 0 ] && $restart; then
    rollback_before_runs="$(service_field runs)"
    rollback_before_pid="$(service_field pid)"
    launchctl kickstart -k "gui/$(id -u)/$SERVICE" 7>&- 8>&-
    ks_rc=$?
    if [ "$ks_rc" -ne 0 ]; then
      helper_log "level=error event=rollback-phase-failed phase=kickstart rc=$ks_rc"
      rollback_rc=1
    fi
  fi
  recovery_unlock

  if [ "$rollback_rc" -eq 0 ] && $restart; then
    local attempt=0 stable=0 current_runs current_pid expect_helper=true
    if [ "$had_binary" != yes ] || $ORIGINAL_CIRCUIT_OPEN || $ROLLBACK_DEGRADED; then
      expect_helper=false
    fi
    while [ "$attempt" -lt 120 ]; do
      attempt=$((attempt + 1))
      current_runs="$(service_field runs)"
      current_pid="$(service_field pid)"
      if [ "$current_runs" = "$((rollback_before_runs + 1))" ] \
        && [ -n "$current_pid" ] && [ "$current_pid" != "$rollback_before_pid" ]; then
        if { $expect_helper && helper_exact_pair "$TARGET" "$SCRIPT_DIR/helper-run.sh" "$BOOTSTRAP"; } \
          || { ! $expect_helper && helper_process_absent "$TARGET" "$SCRIPT_DIR/helper-run.sh" "$BOOTSTRAP"; }; then
          stable=$((stable + 1))
          [ "$stable" -ge 4 ] && break
        else
          stable=0
        fi
      else
        stable=0
      fi
      sleep 0.25 8>&-
    done
    if [ "$stable" -lt 4 ]; then
      helper_log "level=error event=rollback-phase-failed phase=verification before_runs=$rollback_before_runs after_runs=${current_runs:-unknown}"
      rollback_rc=1
    fi
  fi

  if [ "$rollback_rc" -eq 0 ] && enable_hotload; then
    PUBLISHED=false
    ROLLBACK_DONE=true
    ROLLBACK_RUNNING=false
    helper_log "level=warning event=rollback-complete restart=$restart degraded=$ROLLBACK_DEGRADED"
    return 0
  fi

  PRESERVE_WORK=true
  ROLLBACK_RUNNING=false
  helper_log "level=error event=rollback-incomplete work_dir=$WORK_DIR"
  return 1
}

cleanup() {
  local rc=$?
  trap - EXIT HUP INT TERM
  stop_preflight

  if $PUBLISHED && ! $FINALIZED && ! $ROLLBACK_DONE && ! $ROLLBACK_RUNNING; then
    rollback_transaction "$RESTART_REQUESTED" || rc=1
  elif $MARKER_OWNED && ! $FINALIZED && ! $ROLLBACK_RUNNING; then
    if recovery_lock; then
      marker_is_owned && rm -f "$HELPER_RUNTIME_DIR/install-in-progress" 7>&- 8>&-
      recovery_unlock
    fi
  fi

  if [ -n "${STAGING_FILE:-}" ]; then
    if rm -f "$STAGING_FILE" 7>&- 8>&- && [ ! -e "$STAGING_FILE" ]; then
      STAGING_FILE=
    else
      helper_log "level=error event=cleanup-staging-remove-failed path=$STAGING_FILE"
      PRESERVE_WORK=true
      rc=1
    fi
  fi
  if $HOTLOAD_DISABLED && [ -z "${STAGING_FILE:-}" ]; then
    enable_hotload || rc=1
  fi
  if [ -n "${WORK_DIR:-}" ] && ! $PRESERVE_WORK; then
    rm -rf "$WORK_DIR" 7>&- 8>&-
  fi
  exit "$rc"
}
trap cleanup EXIT
trap helper_signal HUP INT TERM

source_digest() {
  find "$SCRIPT_DIR" -maxdepth 1 -type f \
    \( -name '*.c' -o -name '*.h' -o -name '*.m' -o -name makefile \) \
    -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}'
}

service_field() {
  helper_service_field "$1"
}

item_label() {
  sketchybar --query "$1" 2>/dev/null 8>&- |
    awk '/"label": \{/{label=1} label && /"value":/{sub(/^.*"value": "/, ""); sub(/".*$/, ""); print; exit}'
}

metrics_ready() {
  local calendar cpu memory network
  calendar="$(item_label calendar)"
  cpu="$(item_label cpu.user)"
  memory="$(item_label mem.pressure)"
  network="$(item_label network_up)"

  [ -n "$calendar" ] \
    && [ -n "$cpu" ] && [ "$cpu" != "--%" ] \
    && [ -n "$memory" ] && [ "$memory" != "未知" ] \
    && printf '%s' "$network" | grep -Eq '^[0-9]+([.][0-9]+)?$'
}

if [ "$#" -ne 0 ]; then
  printf 'usage: %s\n' "$0" >&2
  exit 64
fi

exec 8>"$HELPER_RUNTIME_DIR/install.lock" || exit 1
if ! /usr/bin/lockf -s -t 10 8; then
  helper_log "level=error event=install-lock-timeout timeout=10"
  exit 1
fi

if [ ! -f "$CONFIG_ROOT/sketchybarrc" ] || [ ! -f "$SCRIPT_DIR/helper.c" ]; then
  helper_log "level=error event=install-layout-invalid config=$CONFIG_ROOT"
  exit 1
fi
for tool in clang file launchctl sketchybar shasum; do
  command -v "$tool" >/dev/null || {
    helper_log "level=error event=install-tool-missing tool=$tool"
    exit 1
  }
done
if [ "$(service_field state)" != running ] || [ -z "$(service_field pid)" ]; then
  helper_log "level=error event=install-service-not-running service=$SERVICE"
  exit 1
fi

PHASE=preflight
WORK_DIR="$(mktemp -d "$HELPER_RUNTIME_DIR/install.XXXXXX" 8>&-)" || exit 1
chmod 700 "$WORK_DIR" 8>&-
candidate="$WORK_DIR/helper"
backup="$WORK_DIR/helper.previous"
original_state="$WORK_DIR/recovery.previous"
before_file="$WORK_DIR/service.before"
ready_fifo="$WORK_DIR/preflight.ready"

digest_before="$( (exec 8>&-; source_digest) )" || exit 1
if ! (exec 8>&-; make -C "$SCRIPT_DIR" OUTPUT="$candidate"); then
  helper_log "level=error event=install-compile-failed"
  exit 1
fi
digest_after="$( (exec 8>&-; source_digest) )" || exit 1
if [ "$digest_before" != "$digest_after" ]; then
  helper_log "level=error event=install-source-changed"
  exit 1
fi
if [ -L "$candidate" ] || [ ! -f "$candidate" ] || [ ! -x "$candidate" ]; then
  helper_log "level=error event=install-candidate-invalid"
  exit 1
fi
if ! file "$candidate" 8>&- | grep -q "$(uname -m 8>&-)" 8>&-; then
  helper_log "level=error event=install-architecture-mismatch expected=$(uname -m 8>&-)"
  exit 1
fi
$INTERRUPTED && exit 130

mkfifo -m 600 "$ready_fifo" 8>&- || exit 1
exec 9<>"$ready_fifo"
preflight_name="git.felix.helper.preflight.$$.$RANDOM"
SKETCHYBAR_HELPER_READY_FIFO="$ready_fifo" "$candidate" "$preflight_name" 7>&- 8>&- 9>&- &
preflight_pid=$!
preflight_identity="$(helper_process_identity "$preflight_pid" 2>/dev/null || true)"
if ! IFS= read -r -t 5 ready <&9 || [ "$ready" != ready ]; then
  helper_log "level=error event=install-preflight-timeout"
  stop_preflight
  exit 1
fi
stop_preflight
exec 9<&-
exec 9>&-
rm -f "$ready_fifo" 8>&-
$INTERRUPTED && exit 130

had_binary=no
backup_hash=
if [ -f "$TARGET" ] && [ ! -L "$TARGET" ]; then
  cp -p "$TARGET" "$backup" 8>&- || exit 1
  backup_hash="$(shasum -a 256 "$backup" 8>&- | awk '{print $1}' 8>&-)"
  had_binary=yes
fi

installer_identity="$(helper_process_identity "$$")" || exit 1
transaction_nonce="$(printf '%s:%s:%s' "$$" "$RANDOM" "$(date +%s 8>&-)" | shasum -a 256 8>&- | awk '{print $1}' 8>&-)"
deadline=$(( $(date +%s 8>&-) + 180 ))

PHASE=activation
if ! recovery_lock; then
  exit 1
fi
state="$HELPER_RUNTIME_DIR/recovery.state"
if [ -e "$state" ]; then
  if [ -L "$state" ] || [ ! -f "$state" ] \
    || [ "$(stat -f '%u' "$state" 2>/dev/null 7>&- 8>&-)" != "$(id -u 7>&- 8>&-)" ] \
    || [ "$(stat -f '%Lp' "$state" 2>/dev/null 7>&- 8>&-)" != 600 ] \
    || [ "$(stat -f '%z' "$state" 2>/dev/null 7>&- 8>&-)" -gt 256 ] \
    || ! cp -p "$state" "$original_state" 7>&- 8>&-; then
    helper_log "level=error event=install-state-snapshot-failed"
    recovery_unlock
    exit 1
  fi
  ORIGINAL_STATE_PRESENT=true
  original_state_hash="$(shasum -a 256 "$original_state" 7>&- 8>&- | awk '{print $1}' 7>&- 8>&-)"
  helper_state_read >/dev/null 2>&1 || true
  [ "$HELPER_RECOVERY_STATUS" = open ] && ORIGINAL_CIRCUIT_OPEN=true
fi

marker_staging="$HELPER_RUNTIME_DIR/.install-in-progress.$transaction_nonce"
printf '%s %s %s %s\n' "$$" "$installer_identity" "$transaction_nonce" "$deadline" > "$marker_staging" \
  && chmod 600 "$marker_staging" 7>&- 8>&- \
  && mv -f "$marker_staging" "$HELPER_RUNTIME_DIR/install-in-progress" 7>&- 8>&- || {
    helper_log "level=error event=install-marker-write-failed"
    recovery_unlock
    exit 1
  }
MARKER_OWNED=true

if ! sketchybar --hotload off 7>&- 8>&-; then
  helper_log "level=error event=install-hotload-disable-failed"
  recovery_unlock
  exit 1
fi
HOTLOAD_DISABLED=true

STAGING_FILE="$SCRIPT_DIR/.helper.install.$transaction_nonce"
if ! cp "$candidate" "$STAGING_FILE" 7>&- 8>&- \
  || ! chmod 700 "$STAGING_FILE" 7>&- 8>&- \
  || ! /bin/sync 7>&- 8>&- \
  || ! mv -f "$STAGING_FILE" "$TARGET" 7>&- 8>&-; then
  helper_log "level=error event=install-publish-failed"
  recovery_unlock
  exit 1
fi
STAGING_FILE=
PUBLISHED=true

printf '%s %s\n' "$(service_field runs)" "$(service_field pid)" > "$before_file" || {
  recovery_unlock
  exit 1
}
RESTART_REQUESTED=true
launchctl kickstart -k "gui/$(id -u)/$SERVICE" 7>&- 8>&-
activation_rc=$?
if [ "$activation_rc" -ne 0 ]; then
  helper_log "level=error event=install-activation-request-failed rc=$activation_rc"
fi
recovery_unlock
[ "$activation_rc" -eq 0 ] || exit 1
$INTERRUPTED && exit 130

read -r before_runs before_pid < "$before_file"
PHASE=activation-verification
stable=0
activation_attempt=0
while [ "$activation_attempt" -lt 120 ] && ! $INTERRUPTED; do
  activation_attempt=$((activation_attempt + 1))
  after_runs="$(service_field runs)"
  after_pid="$(service_field pid)"
  if [ "$after_runs" = "$((before_runs + 1))" ] && [ -n "$after_pid" ] && [ "$after_pid" != "$before_pid" ] \
    && helper_exact_pair "$TARGET" "$SCRIPT_DIR/helper-run.sh" "$BOOTSTRAP"; then
    stable=$((stable + 1))
    [ "$stable" -ge 4 ] && break
  else
    stable=0
  fi
  sleep 0.25 8>&-
done
$INTERRUPTED && exit 130
if [ "$stable" -lt 4 ]; then
  helper_log "level=error event=install-activation-verification-failed before_runs=$before_runs after_runs=${after_runs:-unknown}"
  exit 1
fi

PHASE=metrics-verification
metrics_ok=false
metrics_attempt=0
sketchybar --update >/dev/null 2>&1 8>&- || true
sleep 2 8>&-
while [ "$metrics_attempt" -lt 30 ] && ! $INTERRUPTED; do
  metrics_attempt=$((metrics_attempt + 1))
  if metrics_ready; then
    metrics_ok=true
    break
  fi
  sleep 1 8>&-
done
$INTERRUPTED && exit 130
if ! $metrics_ok; then
  helper_log "level=error event=install-metrics-verification-failed calendar=$(item_label calendar) cpu=$(item_label cpu.user) memory=$(item_label mem.pressure) network=$(item_label network_up)"
  exit 1
fi

PHASE=finalization
if ! enable_hotload; then
  exit 1
fi
if ! recovery_lock; then
  exit 1
fi
if ! marker_is_owned; then
  helper_log "level=error event=install-finalization-failed phase=marker-ownership"
  recovery_unlock
  exit 1
fi
if ! rm -f "$HELPER_RUNTIME_DIR/recovery.state" 7>&- 8>&- \
  || [ -e "$HELPER_RUNTIME_DIR/recovery.state" ]; then
  helper_log "level=error event=install-finalization-failed phase=recovery-state"
  recovery_unlock
  exit 1
fi
if ! rm -f "$HELPER_RUNTIME_DIR/install-in-progress" 7>&- 8>&- \
  || [ -e "$HELPER_RUNTIME_DIR/install-in-progress" ]; then
  helper_log "level=error event=install-finalization-failed phase=marker"
  recovery_unlock
  exit 1
fi
MARKER_OWNED=false
recovery_unlock

FINALIZED=true
PHASE=complete
helper_log "level=info event=install-complete runs=$after_runs pid=$after_pid"
exit 0
