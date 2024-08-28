#!/bin/bash

FRONT_APP_SCRIPT='[ "$SENDER" = "front_app_switched" ] && sketchybar --set $NAME label="$INFO" icon.background.image="app.$INFO"'

front_app=(
  label.font="$FONT:Black:13.0"
  icon.background.drawing=on
  display=active
  script="$FRONT_APP_SCRIPT"
  click_script="open -a 'Mission Control'"
)

sketchybar --add item front_app left         \
           --set front_app "${front_app[@]}" \
           --subscribe front_app front_app_switched