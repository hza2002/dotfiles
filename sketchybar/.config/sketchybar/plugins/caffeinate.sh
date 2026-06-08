#!/bin/bash

# Caffeinate sketchybar plugin.
# State file holds the PID, optional END epoch, and MODE.
# Subcommands: click, forever, hours N, minutes N, until HH:MM, custom, stop, render.

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/spacing.sh"

# Keep in sync with items/caffeinate.sh (IDLE_LABEL only).
IDLE_LABEL="按點下班"
# Active-state prefixes — all four share 班 for typographic continuity.
HOURS_LABEL="加會兒班"
UNTIL_LABEL="加個夜班"
FOREVER_LABEL="不下班了"

STATE_FILE="${TMPDIR:-/tmp}/sketchybar-caffeinate.state"

read_state() {
  PID=""
  END=""
  MODE=""
  [ -f "$STATE_FILE" ] || return
  while IFS='=' read -r k v; do
    case "$k" in
    PID) PID=$v ;;
    END) END=$v ;;
    MODE) MODE=$v ;;
    esac
  done <"$STATE_FILE"
}

is_alive() {
  [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null
}

write_state() {
  {
    echo "PID=$1"
    echo "END=$2"
    echo "MODE=$3"
  } >"$STATE_FILE"
}

cleanup() {
  rm -f "$STATE_FILE"
}

stop() {
  read_state
  is_alive && kill "$PID" 2>/dev/null
  cleanup
}

# Start caffeinate. Args: duration_secs (empty=forever), mode.
# mode: hours | until | forever (empty duration always treated as forever).
start() {
  stop
  local dur="${1:-}"
  local mode="${2:-hours}"
  if [ -n "$dur" ] && [ "$dur" -gt 0 ] 2>/dev/null; then
    caffeinate -i -t "$dur" </dev/null >/dev/null 2>&1 &
    write_state "$!" "$(($(date +%s) + dur))" "$mode"
  else
    caffeinate -i </dev/null >/dev/null 2>&1 &
    write_state "$!" "" "forever"
  fi
  disown
}

# Parse "60" / "1h" / "1h30m" / "90m" -> seconds, or fail.
parse_duration() {
  local input="$1"
  input="${input// /}"
  input=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')
  local secs=0
  if [[ "$input" =~ ^([0-9]+)h([0-9]+)m?$ ]]; then
    secs=$((${BASH_REMATCH[1]} * 3600 + ${BASH_REMATCH[2]} * 60))
  elif [[ "$input" =~ ^([0-9]+)h$ ]]; then
    secs=$((${BASH_REMATCH[1]} * 3600))
  elif [[ "$input" =~ ^([0-9]+)m$ ]]; then
    secs=$((${BASH_REMATCH[1]} * 60))
  elif [[ "$input" =~ ^[0-9]+$ ]]; then
    secs=$((input * 60)) # bare number = minutes
  else
    return 1
  fi
  [ "$secs" -gt 0 ] || return 1
  printf '%s\n' "$secs"
}

custom() {
  local input
  input=$(
    osascript <<'OSA' 2>/dev/null
try
  set d to display dialog "保持唤醒多久？" & return & "格式：60 (分钟) / 1h / 1h30m / 90m" default answer "60" with title "Caffeinate"
  return text returned of d
on error
  return ""
end try
OSA
  )
  [ -z "$input" ] && return 0
  local secs
  if secs=$(parse_duration "$input"); then
    start "$secs" "hours"
  else
    osascript -e "display notification \"无法识别: ${input//\"/\\\"}\" with title \"Caffeinate\"" 2>/dev/null
  fi
}

# Start caffeinate until a given HH:MM.
# Accepts "10:00" (next occurrence, today if upcoming, else tomorrow),
# or "+1d:10:00" (strictly tomorrow's calendar day at HH:MM).
until_time() {
  local arg="$1" hhmm next_day=0
  if [[ "$arg" == "+1d:"* ]]; then
    next_day=1
    hhmm="${arg#+1d:}"
  else
    hhmm="$arg"
  fi
  local target now
  target=$(date -j -f "%H:%M" "$hhmm" +%s 2>/dev/null) || return 1
  now=$(date +%s)
  if [ "$next_day" -eq 1 ]; then
    target=$((target + 86400))
  else
    [ "$target" -le "$now" ] && target=$((target + 86400))
  fi
  start $((target - now)) "until"
}

toggle() {
  read_state
  if is_alive; then
    stop
  else
    start "" "forever"
  fi
}

# Format remaining seconds: <60s as "Ns", else "HhMm" / "Mm".
format_remaining() {
  local secs=$1
  if [ "$secs" -lt 60 ]; then
    printf '%ds' "$secs"
    return
  fi
  local h=$((secs / 3600))
  local m=$(((secs % 3600 + 59) / 60)) # ceil
  if [ "$m" -ge 60 ]; then
    h=$((h + 1))
    m=0
  fi
  if [ "$h" -gt 0 ]; then
    if [ "$m" -gt 0 ]; then
      printf '%dh%dm' "$h" "$m"
    else
      printf '%dh' "$h"
    fi
  else
    printf '%dm' "$m"
  fi
}

render() {
  read_state
  if ! is_alive; then
    [ -f "$STATE_FILE" ] && cleanup
    render_idle
    return
  fi

  # Legacy fallback for state files written before MODE was introduced.
  local mode="$MODE"
  if [ -z "$mode" ]; then
    [ -z "$END" ] && mode="forever" || mode="hours"
  fi

  if [ "$mode" = "forever" ]; then
    sketchybar --set caffeinate \
      label="$FOREVER_LABEL" \
      label.color="$ORANGE_SOFT" \
      label.padding_right=$PAD \
      padding_right=0 \
      label.y_offset=1 \
      update_freq=30 \
      --set caffeinate.suffix \
      label="$CAFFEINATE_FOREVER" \
      label.color="$ORANGE_HARD" \
      label.drawing=on \
      drawing=on
    return
  fi

  # hours / until both have a finite END — handle expiry first.
  local now remaining
  now=$(date +%s)
  remaining=$((END - now))
  if [ "$remaining" -le 0 ]; then
    stop
    render_idle
    return
  fi

  # hours / until both show countdown — only the prefix differentiates.
  local prefix="$HOURS_LABEL"
  [ "$mode" = "until" ] && prefix="$UNTIL_LABEL"

  sketchybar --set caffeinate \
    label="$prefix" \
    label.color="$YELLOW_SOFT" \
    label.padding_right=$PAD \
    padding_right=0 \
    label.y_offset=1 \
    update_freq=30 \
    --set caffeinate.suffix \
    label="$(format_remaining "$remaining")" \
    label.color="$YELLOW_HARD" \
    label.drawing=on \
    drawing=on
}

render_idle() {
  sketchybar --set caffeinate \
    label="$IDLE_LABEL" \
    label.color="$WHITE" \
    label.padding_right=$PAD_WIDE \
    padding_right=$PAD_ITEM \
    label.y_offset=1 \
    update_freq=30 \
    --set caffeinate.suffix label.drawing=off drawing=off
}

# Click handler: left toggles, right opens popup.
click() {
  case "${BUTTON:-left}" in
  right) sketchybar --set caffeinate popup.drawing=toggle ;;
  *) toggle ;;
  esac
}

case "${1:-render}" in
click)
  click
  render
  ;;
toggle)
  toggle
  render
  ;;
stop)
  stop
  render
  ;;
forever)
  start "" "forever"
  render
  ;;
custom)
  custom
  render
  ;;
until)
  until_time "$2"
  render
  ;;
hours)
  start "$((${2:-1} * 3600))" "hours"
  render
  ;;
minutes)
  start "$((${2:-30} * 60))" "hours"
  render
  ;;
render | *) render ;;
esac
