#!/bin/bash

SYSTEM_ITEMS=(cpu mem temp fan power)

hide_all_popups() {
  local args=()
  local item
  for item in "${SYSTEM_ITEMS[@]}"; do
    args+=(--set "$item" popup.drawing=off)
  done
  sketchybar "${args[@]}"
}

refresh_cpu_processes() {
  local ranks=(cpu.process.1 cpu.process.2 cpu.process.3)
  local args=()
  local process
  local index=0

  while IFS= read -r process && [ "$index" -lt 3 ]; do
    [ -n "$process" ] || continue
    args+=(--set "${ranks[$index]}" label="$process")
    index=$((index + 1))
  done < <(ps -Acr -o comm=)

  while [ "$index" -lt 3 ]; do
    args+=(--set "${ranks[$index]}" label="--")
    index=$((index + 1))
  done

  sketchybar "${args[@]}"
}

toggle_popup() {
  local drawing
  drawing=$(sketchybar --query "$NAME" | jq -r '.popup.drawing')

  hide_all_popups
  [ "$drawing" = "off" ] || return

  if [ "$NAME" = "fan" ]; then
    local second_fan
    second_fan=$(sketchybar --query fan.2 | jq -r '.geometry.drawing')
    [ "$second_fan" = "on" ] || return
  elif [ "$NAME" = "cpu" ]; then
    refresh_cpu_processes
  fi

  sketchybar --set "$NAME" popup.drawing=on
}

case "$SENDER" in
  "mouse.clicked")
    if [ "$BUTTON" = "right" ]; then
      hide_all_popups
      if [ "$NAME" = "cpu" ] || [ "$NAME" = "mem" ]; then
        open -a "Activity Monitor"
      fi
    else
      toggle_popup
    fi
    ;;
esac
