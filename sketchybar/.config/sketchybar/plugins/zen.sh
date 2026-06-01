#!/bin/bash

ZEN_ITEMS=(
  wifi
  apple.logo
  '/cpu.*/'
  separator
  spaces.padding
  front_app
  volume_icon
  status.padding
  spotify.anchor
  brew
  mem
  network_up_unit
  network_down_unit
  network_up
  network_down
  fortune
  system
  battery
  "控制中心,com.bjango.istatmenus.sensors"
  "iStat Menus Menubar,com.bjango.istatmenus.weather"
  "控制中心,FocusModes"
)

set_zen_state() {
  local state="$1"
  local args=()

  for item in "${ZEN_ITEMS[@]}"; do
    args+=(--set "$item" drawing="$state")
  done

  args+=(--set calendar icon.drawing="$state")

  if [ "$state" = "off" ]; then
    args+=(--set spotify.play updates=off)
  else
    args+=(--set spotify.play updates=on)
  fi

  sketchybar "${args[@]}"
}

if [ "$1" = "on" ]; then
  set_zen_state off
elif [ "$1" = "off" ]; then
  set_zen_state on
else
  if [ "$(sketchybar --query apple.logo | jq -r ".geometry.drawing")" = "on" ]; then
    set_zen_state off
  else
    set_zen_state on
  fi
fi
