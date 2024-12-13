#!/bin/bash

source "CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

wifi=(
  padding_left=0
  padding_right=10
  label.width=0
  icon="$WIFI_DISCONNECTED"
  script="$PLUGIN_DIR/wifi.sh"
  icon.color=$BLUE_SOFT
)

sketchybar --add item wifi right \
           --set wifi "${wifi[@]}" \
           --subscribe wifi wifi_change mouse.clicked
