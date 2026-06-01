#!/bin/bash

network_up=(
  icon=􀆇 
  label.font="$FONT:Semibold:10.0" 
  icon.font="$FONT:Bold:10.0" 
  icon.highlight_color="$BLUE" 
  y_offset=5 
  script="$PLUGIN_DIR/network.sh" 
  update_freq=2
  width=0
  label.width=26
  label.align=right
  icon.padding_right=1
)

network_down=(
  icon=􀆈 
  label.font="$FONT:Semibold:10.0" 
  icon.font="$FONT:Bold:10.0" 
  icon.highlight_color="$YELLOW" 
  y_offset=-5 
  script="$PLUGIN_DIR/network.sh" 
  update_freq=2
  width=40
  label.width=26
  label.align=right
  icon.padding_right=1
)

network_up_unit=(
  icon.drawing=off
  label.font="$FONT:Semibold:10.0"
  y_offset=5
  width=0
  label.width=26
  label.align=left
)

network_down_unit=(
  icon.drawing=off
  label.font="$FONT:Semibold:10.0"
  y_offset=-5
  width=26
  label.width=26
  label.align=left
)

sketchybar -m --add item network_up_unit right \
              --set network_up_unit "${network_up_unit[@]}" \
              --add item network_down_unit right \
              --set network_down_unit "${network_down_unit[@]}" \
              --add item network_up right \
              --set network_up "${network_up[@]}" \
              --add item network_down right \
              --set network_down "${network_down[@]}"
