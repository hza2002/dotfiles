#!/bin/bash

battery=(
  script="$PLUGIN_DIR/battery.sh"
  icon.font="$FONT_ICON:Regular:19.0"
  icon.padding_right=5
  label="$LOADING"
  label.width=dynamic
  label.align=left
  update_freq=30
  popup.align=center
  padding_right=$PAD_WIDE
)
$HELPER_AVAILABLE && battery+=(mach_helper="$HELPER")

battery_status=(
  icon.drawing=off
  label="未知: 暂无估算"
  label.width=dynamic
  label.align=center
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  script="$PLUGIN_DIR/battery.sh"
)

sketchybar --add item battery right \
  --set battery "${battery[@]}" \
  --set battery popup.drawing=off \
  --subscribe battery power_source_change \
  system_woke \
  mouse.clicked \
  mouse.exited.global \
  \
  --add item battery.status popup.battery \
  --set battery.status "${battery_status[@]}" \
  --subscribe battery.status mouse.exited.global
