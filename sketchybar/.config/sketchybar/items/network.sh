#!/bin/bash

network_up=(
  icon=$NETWORK_UP
  label.font="$FONT_MAIN:Bold:10.0"
  icon.font="$FONT_ICON:Bold:10.0"
  icon.highlight_color="$BLUE"
  y_offset=5
  update_freq=3
  mach_helper="$HELPER"
  width=0
  label.width=26
  label.align=right
)

network_down=(
  icon=$NETWORK_DOWN
  label.font="$FONT_MAIN:Bold:10.0"
  icon.font="$FONT_ICON:Bold:10.0"
  icon.highlight_color="$YELLOW"
  y_offset=-5
  width=40
  label.width=26
  label.align=right
)

network_up_unit=(
  icon.drawing=off
  label.font="$FONT_MAIN:Bold:10.0"
  y_offset=5
  width=0
  label.width=26
  label.align=left
)

network_down_unit=(
  icon.drawing=off
  label.font="$FONT_MAIN:Bold:10.0"
  y_offset=-5
  width=26
  label.width=26
  label.align=left
)

sketchybar --add item network_up_unit right \
              --set network_up_unit "${network_up_unit[@]}" \
              --add item network_down_unit right \
              --set network_down_unit "${network_down_unit[@]}" \
              --add item network_up right \
              --set network_up "${network_up[@]}" \
              --add item network_down right \
              --set network_down "${network_down[@]}"
