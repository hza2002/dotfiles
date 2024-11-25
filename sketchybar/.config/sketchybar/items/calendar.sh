#!/bin/bash

calendar=(
  icon=cal
  icon.font="$FONT:Black:12.0"
  label.width=45
  label.align=right
  icon.padding_right=-2
  padding_left=15
  padding_right=5
  update_freq=30
  script="$PLUGIN_DIR/calendar.sh"
  click_script="$PLUGIN_DIR/zen.sh"
)

sketchybar --add item calendar right       \
           --set calendar "${calendar[@]}" \
           --subscribe calendar system_woke
