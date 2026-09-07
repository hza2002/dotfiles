#!/bin/bash

# Battery popup click handler. The mach helper renders the bar item, while this
# script runs only from click_script, so routine updates never fork a shell.

open_popup() {
  BATTERY_INFO="$(pmset -g batt)"
  local parsed
  parsed=$(awk -F'; ' '/InternalBattery/ {
    states = states $2 "\n"
    split($3, estimate, " ")
    estimates = estimates estimate[1] "\n"
  }
  END {
    sub(/\n$/, "", states)
    sub(/\n$/, "", estimates)
    printf "%s|%s", states, estimates
  }' <<< "$BATTERY_INFO")
  STATE="${parsed%|*}"
  ESTIMATE="${parsed##*|}"
  HAS_ESTIMATE=false

  case "$ESTIMATE" in
    [0-9]*:[0-9][0-9]) HAS_ESTIMATE=true ;;
  esac

  STATUS="未知"
  ESTIMATE_LABEL="暂无估算"

  if [[ "$BATTERY_INFO" == *'AC Power'* ]]; then
    case "$STATE" in
      *charged*) STATUS="已充满" ;;
      *"finishing charge"*) STATUS="充电中" ;;
      *) STATUS="充电中" ;;
    esac

    if [ "$ESTIMATE" = "0:00" ] && [ "$STATUS" != "已充满" ]; then
      ESTIMATE_LABEL="即将充满"
    elif [ "$HAS_ESTIMATE" = "true" ] && [ "$STATUS" != "已充满" ]; then
      ESTIMATE_LABEL="$ESTIMATE 后满"
    elif [ "$STATUS" = "已充满" ]; then
      ESTIMATE_LABEL="无需充电"
    fi
  else
    STATUS="电池供电"
    if [ "$HAS_ESTIMATE" = "true" ]; then
      ESTIMATE_LABEL="可用 $ESTIMATE"
    fi
  fi

  sketchybar --set battery.status label="$STATUS: $ESTIMATE_LABEL" \
             --set battery popup.drawing=on
}

toggle_popup() {
  DRAWING=$(sketchybar --query battery | jq -r '.popup.drawing')
  if [ "$DRAWING" = "off" ]; then
    open_popup
  else
    sketchybar --set battery popup.drawing=off
  fi
}

case "$SENDER" in
  "mouse.clicked") toggle_popup ;;
esac
