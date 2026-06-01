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

toggle_devices() {
  which SwitchAudioSource >/dev/null || exit 0
  source "$CONFIG_DIR/colors.sh"

  args=(--remove '/volume.device\.*/' --set "$NAME" popup.drawing=toggle)
  COUNTER=0
  CURRENT="$(SwitchAudioSource -t output -c)"
  while IFS= read -r device; do
    COLOR=$GREY
    if [ "${device}" = "$CURRENT" ]; then
      COLOR=$WHITE
    fi
    args+=(--add item volume.device."$COUNTER" popup."$NAME" \
           --set volume.device."$COUNTER" label="${device}" \
                                        label.color="$COLOR" \
                                        script="$PLUGIN_DIR/volume_click.sh" \
                 click_script="SwitchAudioSource -s \"${device}\" && sketchybar --set /volume.device\.*/ label.color=$GREY --set \$NAME label.color=$WHITE --set volume_icon popup.drawing=off" \
           --subscribe volume.device."$COUNTER" mouse.exited.global)
    COUNTER=$((COUNTER+1))
  done <<< "$(SwitchAudioSource -a -t output)"

  sketchybar -m "${args[@]}" > /dev/null
}

collapse_devices() {
  sketchybar --remove '/volume.device\.*/' \
             --set volume_icon popup.drawing=off
}

scroll_volume() {
  local delta
  delta="${SCROLL_DELTA:-}"

  if [ -z "$delta" ] && command -v jq >/dev/null 2>&1; then
    delta="$(printf '%s' "$INFO" | jq -r '.delta // empty' 2>/dev/null)"
  fi

  case "$delta" in
    ''|*[!0-9-]*) exit 0 ;;
  esac

  if [ "${MODIFIER:-}" != "ctrl" ]; then
    delta=$((delta * 10))
  fi

  osascript -e "set volume output volume (output volume of (get volume settings) + $delta)"
}

case "$SENDER" in
  "mouse.scrolled") scroll_volume
  ;;
  "mouse.exited.global") collapse_devices
  ;;
  *)
    if [ "$BUTTON" = "right" ]; then
      toggle_devices
    else
      toggle_detail
    fi
  ;;
esac
