#!/bin/bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

set_popup_info() {
  BATTERY_INFO="$(pmset -g batt)"
  PERCENTAGE=$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)
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
  DRAWING=$(sketchybar --query "$NAME" | jq -r '.popup.drawing')
  sketchybar --set "$NAME" popup.drawing=toggle

  if [ "$DRAWING" = "off" ]; then
    set_popup_info
  fi
}

hide_popup() {
  sketchybar --set battery popup.drawing=off
}

case "$SENDER" in
  "mouse.clicked") toggle_popup; exit 0 ;;
  "mouse.exited.global") hide_popup; exit 0 ;;
esac

BATTERY_INFO="$(pmset -g batt)"
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(echo "$BATTERY_INFO" | grep 'AC Power')

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

DRAWING=on
COLOR=$WHITE
case ${PERCENTAGE} in
  9[0-9]|100) ICON=$BATTERY_100; COLOR=$AQUA_HARD
  ;;
  8[0-9]) ICON=$BATTERY_75; COLOR=$GREEN_SOFT
  ;;
  7[0-9]) ICON=$BATTERY_75; COLOR=$GREEN_HARD
  ;;
  6[0-9]) ICON=$BATTERY_75; COLOR=$YELLOW_SOFT
  ;;
  5[0-9]) ICON=$BATTERY_50; COLOR=$YELLOW_HARD
  ;;
  4[0-9]) ICON=$BATTERY_50; COLOR=$ORANGE_SOFT
  ;;
  3[0-9]) ICON=$BATTERY_25; COLOR=$ORANGE_HARD
  ;;
  2[0-9]) ICON=$BATTERY_25; COLOR=$RED_SOFT
  ;;
  1[0-9]) ICON=$BATTERY_0; COLOR=$RED_HARD
  ;;
  *) ICON=$BATTERY_0; COLOR=$RED_HARD
esac

if [[ $CHARGING != "" ]]; then
  COLOR=$AQUA_SOFT
  ICON=$BATTERY_CHARGING
  # DRAWING=off
fi

LEAD=""
if [ "$PERCENTAGE" -lt 10 ]; then
  LEAD="0"
fi

sketchybar --set "$NAME" drawing="$DRAWING" icon="$ICON" icon.color="$COLOR" label="$LEAD$PERCENTAGE%"
