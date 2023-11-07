#!/bin/bash

network_up=(
  icon=􀆇 
  label.font="$FONT:Semibold:10.0" 
  icon.font="$FONT:Bold:10.0" 
  icon.highlight_color="$BLUE" 
  y_offset=5 
  script="$PLUGIN_DIR/network.sh" 
  update_freq=1 
  width=0
  label.width=55
)

network_down=(
  icon=􀆈 
  label.font="$FONT:Semibold:10.0" 
  icon.font="$FONT:Bold:10.0" 
  icon.highlight_color="$YELLOW" 
  y_offset=-5 
  script="$PLUGIN_DIR/network.sh" 
  update_freq=1
  width=70
  label.width=55
)

sketchybar -m --add item network_up right \
              --set network_up "${network_up[@]}"

sketchybar -m --add item network_down right\
              --set network_down "${network_down[@]}"
