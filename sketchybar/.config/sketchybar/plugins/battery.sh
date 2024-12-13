#!/bin/bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

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

sketchybar --set "$NAME" drawing="$DRAWING" icon="$ICON" icon.color="$COLOR"
