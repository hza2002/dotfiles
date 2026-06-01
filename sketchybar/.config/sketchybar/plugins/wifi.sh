#!/bin/bash

update() {
  source "$CONFIG_DIR/icons.sh"
  source "$CONFIG_DIR/colors.sh"
  IP="$(ipconfig getifaddr en0)"
  LABEL="$INFO $IP"
  ICON="$([ -n "$IP" ] && echo "$WIFI_CONNECTED" || echo "$WIFI_DISCONNECTED")"
  COLOR="$BLUE_SOFT"

  sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="$LABEL"
}

set_details() {
  IP="$(ipconfig getifaddr en0)"
  if [ -z "$IP" ]; then
    sketchybar --set wifi.ip label="IP: 未连接" \
               --set wifi.gateway drawing=off
    return
  fi

  WIFI_INFO="$(networksetup -getinfo Wi-Fi 2>/dev/null)"
  ROUTER="$(echo "$WIFI_INFO" | awk -F 'Router: ' '/^Router: / {print $2}')"

  [ -z "$ROUTER" ] && ROUTER="无网关"

  sketchybar --set wifi.ip drawing=on label="IP: $IP" \
             --set wifi.gateway drawing=on label="网关: $ROUTER"
}

click() {
  DRAWING="$(sketchybar --query "$NAME" | jq -r '.popup.drawing')"
  sketchybar --set "$NAME" popup.drawing=toggle

  if [ "$DRAWING" = "off" ]; then
    set_details
  fi
}

hide() {
  sketchybar --set wifi popup.drawing=off
}

case "$SENDER" in
  "wifi_change"|"system_woke"|"forced"|"routine") update
  ;;
  "mouse.clicked") click
  ;;
  "mouse.exited.global") hide
  ;;
esac
