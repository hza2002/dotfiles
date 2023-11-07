#!/bin/bash

mem=(
  icon=􀫦 
  icon.padding_left=8 
  label.font="$FONT:BOLD:13.0" 
  icon.color=0xFFFFFFFF 
  label.color=0xFFFFFFFF
  background.height=24 
  background.corner_radius=4 
  label.padding_right=8
  script="$PLUGIN_DIR/mem.sh" 
  update_freq=2
)

sketchybar -m --add item mem right \
              --set mem "${mem[@]}"

sketchybar --add bracket system "iStat Menus Status,com.bjango.istatmenus.sensors" mem
