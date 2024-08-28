#!/bin/bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

if [ "$SENDER" = "svim_update" ]; then
  COLOR=$WHITE
  case "$MODE" in
    "N") ICON="$MODE_NORMAL" COLOR=$BLUE
    ;;
    "I") ICON="$MODE_INSERT" COLOR=$GREEN
    ;;
    "V") ICON="$MODE_VISUAL" COLOR=$ORANGE
    ;;
    "C") ICON="$MODE_CMD" COLOR=$RED
    ;;
    "_") ICON="$MODE_PENDING" COLOR=$WHITE
    ;;
    *) ICON="$MODE_PENDING" COLOR=$WHITE
    ;;
  esac

  sketchybar --set svim label="$ICON$CMDLINE" \
                        label.color="$COLOR" 
fi
