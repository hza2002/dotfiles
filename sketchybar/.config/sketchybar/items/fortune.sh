#!/bin/bash

source "CONFIG_DIR/colors.sh"

fortune=(
  label="按点下班"
  label.font="$FONT:BOLD:10.0"
  label.color="$ORANGE"
  script="$PLUGIN_DIR/fortune.sh"
  update_freq=600
)

sketchybar -m --add item fortune left \
              --set fortune "${fortune[@]}"
