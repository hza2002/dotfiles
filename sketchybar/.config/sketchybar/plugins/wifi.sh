#!/bin/bash

CACHE_FILE="/tmp/sketchybar_wifi_public.cache"
CACHE_TTL=300  # 5 minutes

get_public_info() {
  # Return cached result if still fresh
  if [ -f "$CACHE_FILE" ] && [ "$(stat -f %m "$CACHE_FILE" 2>/dev/null)" ]; then
    local now cache_time
    now="$(date +%s)"
    cache_time="$(stat -f %m "$CACHE_FILE")"
    if [ $((now - cache_time)) -lt $CACHE_TTL ]; then
      cat "$CACHE_FILE"
      return
    fi
  fi

  local result
  result="$(curl -s --connect-timeout 3 --max-time 5 'http://ip-api.com/json/?fields=query,country,countryCode' 2>/dev/null)"
  if [ -n "$result" ]; then
    echo "$result" > "$CACHE_FILE"
    echo "$result"
  elif [ -f "$CACHE_FILE" ]; then
    # On error, return stale cache if available
    cat "$CACHE_FILE"
  fi
}

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
    sketchybar --set wifi.ip label="内网: 未连接" \
               --set wifi.gateway drawing=off \
               --set wifi.public_ip drawing=off \
               --set wifi.country drawing=off
    return
  fi

  WIFI_INFO="$(networksetup -getinfo Wi-Fi 2>/dev/null)"
  ROUTER="$(echo "$WIFI_INFO" | awk -F 'Router: ' '/^Router: / {print $2}')"

  [ -z "$ROUTER" ] && ROUTER="无网关"

  sketchybar --set wifi.ip drawing=on label="内网: $IP" \
             --set wifi.gateway drawing=on label="网关: $ROUTER"

  # Fetch public IP info (cached). Parse with a single jq call instead of
  # spawning python3 three times — each python3 startup is ~50ms.
  local public_info public_ip country_code country country_label
  public_info="$(get_public_info)"
  if [ -n "$public_info" ]; then
    IFS=$'\t' read -r public_ip country country_code <<<"$(
      printf '%s' "$public_info" \
        | jq -r '[.query // "未知", .country // "未知", .countryCode // ""] | @tsv' 2>/dev/null
    )"
  fi
  [ -z "$public_ip" ] && public_ip="获取失败"
  [ -z "$country" ]   && country="未知"

  country_label="$country"
  [ -n "$country_code" ] && country_label="$country ($country_code)"

  sketchybar --set wifi.public_ip drawing=on label="公网: $public_ip" \
             --set wifi.country drawing=on label="地区: $country_label"
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
