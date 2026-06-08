#!/bin/bash

# CPU / MEM / TEMP / POWER share visuals and a mach helper data source.
# Order of registration controls right-to-left order in the bar.
add_system_widget() {
  local name=$1 icon=$2 icon_size=$3 label_size=$4 freq=$5
  local defaults=(
    icon="$icon"
    icon.font="$FONT_ICON:Bold:$icon_size"
    icon.padding_left=8
    label.font="$FONT_MAIN:Bold:$label_size"
    icon.color="$WHITE"
    label.color="$WHITE"
    background.height=26
    background.corner_radius=4
    label.padding_right=8
    update_freq="$freq"
    mach_helper="$HELPER"
  )
  sketchybar --add item "$name" right --set "$name" "${defaults[@]}"
}

add_system_widget fan   "$SYS_FAN"          15 13 5
add_system_widget temp  "$SYS_TEMP_MEDIUM" 15 13 5
add_system_widget power "$SYS_POWER"       15 13 3
add_system_widget mem   "$SYS_MEM"         16 14 15
add_system_widget cpu   "$SYS_CPU"         16 14 3
