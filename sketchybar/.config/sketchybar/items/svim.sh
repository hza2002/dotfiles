#!/bin/bash

svim=(
  script="$PLUGIN_DIR/svim.sh"
  label=$MODE_PENDING
  label.font="Hack Nerd Font Mono:Bold:29.0" 
  padding_left=0
  padding_right=0
  y_offset=1
)

sketchybar --add event svim_update \
           --add item svim right   \
           --set svim "${svim[@]}" \
           --subscribe svim svim_update window_focus
