#!/bin/bash

helper_log() {
  printf 'ts=%s component=helper-lifecycle %s\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

helper_runtime_init() {
  local uid owner mode

  uid="$(id -u 7>&- 8>&-)"
  HELPER_RUNTIME_DIR="${SKETCHYBAR_HELPER_RUNTIME_DIR:-${TMPDIR:-/tmp}/sketchybar-helper-$uid}"

  if [ -L "$HELPER_RUNTIME_DIR" ] || { [ -e "$HELPER_RUNTIME_DIR" ] && [ ! -d "$HELPER_RUNTIME_DIR" ]; }; then
    helper_log "level=error event=runtime-dir-invalid path=$HELPER_RUNTIME_DIR"
    return 1
  fi

  if [ ! -d "$HELPER_RUNTIME_DIR" ]; then
    umask 077
    mkdir -m 700 "$HELPER_RUNTIME_DIR" 7>&- 8>&- || return 1
  fi

  owner="$(stat -f '%u' "$HELPER_RUNTIME_DIR" 2>/dev/null 7>&- 8>&-)" || return 1
  mode="$(stat -f '%Lp' "$HELPER_RUNTIME_DIR" 2>/dev/null 7>&- 8>&-)" || return 1
  if [ "$owner" != "$uid" ] || [ "$mode" != 700 ]; then
    helper_log "level=error event=runtime-dir-insecure owner=$owner mode=$mode path=$HELPER_RUNTIME_DIR"
    return 1
  fi

  export HELPER_RUNTIME_DIR
  umask 077
}

helper_process_identity() {
  local pid="${1:?pid required}" started
  case "$pid" in *[!0-9]*|'') return 1 ;; esac
  started="$(ps -o lstart= -p "$pid" 2>/dev/null 7>&- 8>&-)" || return 1
  [ -n "$started" ] || return 1
  printf '%s' "$started" | shasum -a 256 7>&- 8>&- | awk '{print $1}' 7>&- 8>&-
}

helper_marker_valid() {
  local marker="$HELPER_RUNTIME_DIR/install-in-progress"
  local pid identity nonce deadline now actual owner mode extra

  [ -f "$marker" ] && [ ! -L "$marker" ] || return 1
  owner="$(stat -f '%u' "$marker" 2>/dev/null 7>&- 8>&-)" || return 1
  mode="$(stat -f '%Lp' "$marker" 2>/dev/null 7>&- 8>&-)" || return 1
  [ "$owner" = "$(id -u 7>&- 8>&-)" ] && [ "$mode" = 600 ] || return 1
  [ "$(stat -f '%z' "$marker" 2>/dev/null 7>&- 8>&-)" -le 512 ] || return 1

  read -r pid identity nonce deadline extra < "$marker" || return 1
  [ -z "${extra:-}" ] || return 1
  case "$pid:$deadline" in *[!0-9:]*|:*) return 1 ;; esac
  case "$identity:$nonce" in *[!0-9a-f:]*|:*) return 1 ;; esac
  now="$(date +%s 7>&- 8>&-)"
  [ "$deadline" -ge "$now" ] || return 1
  actual="$(helper_process_identity "$pid")" || return 1
  [ "$actual" = "$identity" ]
}

helper_state_read() {
  local state="$HELPER_RUNTIME_DIR/recovery.state"
  HELPER_RECOVERY_STATUS=closed
  HELPER_RECOVERY_FAILURES=0

  [ -e "$state" ] || return 0
  if [ -L "$state" ] || [ ! -f "$state" ] \
    || [ "$(stat -f '%u' "$state" 2>/dev/null 7>&- 8>&-)" != "$(id -u 7>&- 8>&-)" ] \
    || [ "$(stat -f '%Lp' "$state" 2>/dev/null 7>&- 8>&-)" != 600 ] \
    || [ "$(stat -f '%z' "$state" 2>/dev/null 7>&- 8>&-)" -gt 256 ]; then
    HELPER_RECOVERY_STATUS=open
    HELPER_RECOVERY_FAILURES=2
    return 1
  fi

  local status failures extra
  read -r status failures extra < "$state" || {
    HELPER_RECOVERY_STATUS=open
    HELPER_RECOVERY_FAILURES=2
    return 1
  }
  case "$status" in closed|open) ;; *) status=open ;; esac
  case "$failures" in *[!0-9]*|'') status=open; failures=2 ;; esac
  [ -z "${extra:-}" ] || {
    status=open
    failures=2
  }
  HELPER_RECOVERY_STATUS="$status"
  HELPER_RECOVERY_FAILURES="$failures"
  [ "$status" != open ]
}

helper_state_write() {
  local status="${1:?status required}" failures="${2:?failures required}"
  local state="$HELPER_RUNTIME_DIR/recovery.state"
  local staging="$HELPER_RUNTIME_DIR/.recovery.state.$$"

  case "$status" in closed|open) ;; *) return 1 ;; esac
  case "$failures" in *[!0-9]*|'') return 1 ;; esac

  printf '%s %s\n' "$status" "$failures" > "$staging" || return 1
  chmod 600 "$staging" 7>&- 8>&- || return 1
  mv -f "$staging" "$state" 7>&- 8>&-
}

helper_service_field() {
  local field="${1:?field required}"
  launchctl print "gui/$(id -u 7>&- 8>&-)/homebrew.mxcl.sketchybar" 2>/dev/null 7>&- 8>&- |
    awk -v field="$field" '$1 == field && $2 == "=" { print $3; exit }' 7>&- 8>&-
}

helper_exact_pair() {
  local binary="${1:?binary required}" wrapper="${2:?wrapper required}"
  local bootstrap="${3:?bootstrap required}"
  local pid ppid pgid command helper_pid= helper_parent= helper_pgid=
  local wrapper_pid= wrapper_pgid= helper_count=0 wrapper_count=0
  local service_pid

  while read -r pid ppid pgid command; do
    if [ "$command" = "$binary $bootstrap" ]; then
      helper_pid="$pid"
      helper_parent="$ppid"
      helper_pgid="$pgid"
      helper_count=$((helper_count + 1))
    elif [ "$command" = "/bin/bash $wrapper $bootstrap" ]; then
      wrapper_pid="$pid"
      wrapper_pgid="$pgid"
      wrapper_count=$((wrapper_count + 1))
    fi
  done < <(ps -axo pid=,ppid=,pgid=,command= 7>&- 8>&-)

  service_pid="$(helper_service_field pid)"
  [ "$helper_count" -eq 1 ] && [ "$wrapper_count" -eq 1 ] \
    && [ "$helper_parent" = "$wrapper_pid" ] \
    && [ "$helper_pgid" = "$wrapper_pgid" ] \
    && [ "$wrapper_pgid" = "$service_pid" ]
}

helper_process_absent() {
  local binary="${1:?binary required}" wrapper="${2:?wrapper required}"
  local bootstrap="${3:?bootstrap required}"
  local pid ppid command snapshot

  snapshot="$(ps -axo pid=,ppid=,command= 7>&- 8>&-)" || return 1
  while read -r pid ppid command; do
    if [ "$command" = "$binary $bootstrap" ] \
      || [ "$command" = "/bin/bash $wrapper $bootstrap" ]; then
      return 1
    fi
  done <<< "$snapshot"
  return 0
}
