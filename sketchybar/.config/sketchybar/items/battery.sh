#!/bin/bash

battery=(
  script="$PLUGIN_DIR/battery.sh"
  icon.font="$FONT:Regular:19.0"
  padding_right=6
  padding_left=0
  icon.padding_right=5
  label="$LOADING"
  label.width=dynamic
  label.align=left
  label.padding_left=0
  update_freq=120
  updates=on
  popup.align=center
)

battery_status=(
  icon.drawing=off
  label="未知: 暂无估算"
  label.width=dynamic
  label.align=center
  label.padding_left=10
  label.padding_right=10
  script="$PLUGIN_DIR/battery.sh"
)

sketchybar --add item battery right                \
           --set battery "${battery[@]}"           \
           --subscribe battery power_source_change \
                              system_woke          \
                              mouse.clicked        \
                              mouse.exited.global  \
                                                     \
           --add item battery.status popup.battery \
           --set battery.status "${battery_status[@]}" \
           --subscribe battery.status mouse.exited.global
