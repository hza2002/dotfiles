#!/bin/bash

WIDTH=100

detail_on() {
  sketchybar --animate tanh 30 --set volume slider.width=$WIDTH
}

detail_off() {
  sketchybar --animate tanh 30 --set volume slider.width=0
}

toggle_detail() {
  INITIAL_WIDTH=$(sketchybar --query volume | jq -r ".slider.width")
  if [ "$INITIAL_WIDTH" -eq "0" ]; then
    detail_on
  else
    detail_off
  fi
}

device_items_exist() {
  sketchybar --query bar 2>/dev/null \
    | jq -e '.items | any(startswith("volume.device."))' >/dev/null 2>&1
}

toggle_devices() {
  local volume_plugin="$CONFIG_DIR/plugins/volume_click.sh"
  local drawing

  command -v SwitchAudioSource >/dev/null 2>&1 || exit 0
  source "$CONFIG_DIR/colors.sh"

  drawing="$(sketchybar --query "$NAME" | jq -r '.popup.drawing // "off"')"
  if [ "$drawing" = "on" ]; then
    sketchybar --remove '/volume.device\.*/' \
               --set "$NAME" popup.drawing=off
    return
  fi

  args=()
  device_items_exist && args+=(--remove '/volume.device\.*/')
  args+=(--set "$NAME" popup.drawing=on)
  COUNTER=0
  CURRENT="$(SwitchAudioSource -t output -c)"
  while IFS= read -r device; do
    COLOR=$GRAY
    if [ "${device}" = "$CURRENT" ]; then
      COLOR=$WHITE
    fi
    args+=(--add item volume.device."$COUNTER" popup."$NAME" \
           --set volume.device."$COUNTER" label="${device}" \
                                        label.color="$COLOR" \
                 click_script="SENDER=mouse.clicked \"$volume_plugin\"")
    COUNTER=$((COUNTER+1))
  done <<< "$(SwitchAudioSource -a -t output)"

  sketchybar -m "${args[@]}" > /dev/null
}

select_device() {
  local device volume

  device="$(sketchybar --query "$NAME" 2>/dev/null \
    | jq -r '.label.value // empty')" || return 0
  [ -n "$device" ] || return 0

  SwitchAudioSource -s "$device" >/dev/null || return 0

  source "$CONFIG_DIR/colors.sh"
  sketchybar --set '/volume.device\.*/' label.color="$GRAY" \
             --set "$NAME" label.color="$WHITE" \
             --set volume_icon popup.drawing=off

  volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
  sketchybar --trigger volume_change INFO="${volume:-0}"
}

scroll_volume() {
  local delta
  delta="${SCROLL_DELTA:-}"

  if [ -z "$delta" ] && command -v jq >/dev/null 2>&1; then
    delta="$(printf '%s' "$INFO" | jq -r '.delta // empty' 2>/dev/null)"
  fi

  [[ "$delta" =~ ^-?([0-9]|10)$ ]] || exit 0

  if [ "${MODIFIER:-}" != "ctrl" ]; then
    delta=$((delta * 10))
  fi

  osascript -e "set volume output volume (output volume of (get volume settings) + $delta)"
}

case "$SENDER" in
  "mouse.scrolled") scroll_volume
  ;;
  "mouse.clicked")
    case "$NAME" in
      volume.device.*) select_device ;;
      *)
        if [ "${BUTTON:-}" = "right" ]; then
          toggle_devices
        else
          toggle_detail
        fi
        ;;
    esac
  ;;
esac
