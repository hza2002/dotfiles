#!/bin/bash

source "$CONFIG_DIR/colors.sh"

mem=(
  icon=􀫦 
  icon.padding_left=8 
  label.font="$FONT:Bold:13.0"
  icon.color=$WHITE
  label.color=$WHITE
  background.height=24 
  background.corner_radius=4 
  label.padding_right=8
  script="$PLUGIN_DIR/mem.sh" 
  update_freq=2
)

sketchybar -m --add item mem right \
              --set mem "${mem[@]}"

sketchybar --add bracket system "控制中心,com.bjango.istatmenus.sensors" mem
