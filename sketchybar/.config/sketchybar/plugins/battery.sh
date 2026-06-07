#!/bin/bash

# Battery click / popup handler. The label + icon are rendered by the
# mach helper (IOKit, no forks). This script runs on subscribed events:
#  - mouse.clicked on `battery` → toggle popup
#  - mouse.exited.global on `battery` / `battery.status` → hide popup

set_popup_info() {
  BATTERY_INFO="$(pmset -g batt)"
  STATE=$(echo "$BATTERY_INFO" | awk -F'; ' '/InternalBattery/ {print $2}')
  ESTIMATE=$(echo "$BATTERY_INFO" | awk -F'; ' '/InternalBattery/ {print $3}' | awk '{print $1}')
  HAS_ESTIMATE=false

  case "$ESTIMATE" in
    [0-9]*:[0-9][0-9]) HAS_ESTIMATE=true ;;
  esac

  STATUS="未知"
  ESTIMATE_LABEL="暂无估算"

  if echo "$BATTERY_INFO" | grep -q 'AC Power'; then
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

  sketchybar --set battery.status label="$STATUS: $ESTIMATE_LABEL"
}

toggle_popup() {
  DRAWING=$(sketchybar --query battery | jq -r '.popup.drawing')
  sketchybar --set battery popup.drawing=toggle
  if [ "$DRAWING" = "off" ]; then
    set_popup_info
  fi
}

hide_popup() {
  sketchybar --set battery popup.drawing=off
}

case "$SENDER" in
  "mouse.exited.global") hide_popup ;;
  "mouse.clicked") toggle_popup ;;
  *) ;; # forced, power_source_change, system_woke → noop
esac
