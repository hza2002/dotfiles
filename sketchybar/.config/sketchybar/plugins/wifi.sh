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

get_wifi_info() {
  networksetup -getinfo Wi-Fi 2>/dev/null
}

get_wifi_value() {
  local key=$1
  awk -F ': ' -v key="$key" '$1 == key { print $2; exit }'
}

update() {
  source "$CONFIG_DIR/icons.sh"
  source "$CONFIG_DIR/colors.sh"
  WIFI_INFO="$(get_wifi_info)"
  IP="$(get_wifi_value "IP address" <<<"$WIFI_INFO")"
  [ "$IP" = "none" ] && IP=""
  LABEL="$INFO $IP"
  ICON="$([ -n "$IP" ] && echo "$WIFI_CONNECTED" || echo "$WIFI_DISCONNECTED")"
  COLOR="$BLUE_SOFT"

  sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="$LABEL"

  # Pre-warm the public-IP cache in the background. By the time the user
  # clicks the popup, get_public_info() inside set_details() is a cache hit
  # and the popup can open with all four rows already populated.
  if [ -n "$IP" ]; then
    ( get_public_info >/dev/null 2>&1 & ) >/dev/null 2>&1
  fi
}

set_details() {
  WIFI_INFO="$(get_wifi_info)"
  IP="$(get_wifi_value "IP address" <<<"$WIFI_INFO")"
  [ "$IP" = "none" ] && IP=""
  if [ -z "$IP" ]; then
    sketchybar --set wifi.ip         drawing=on  label="内网: 未连接" \
               --set wifi.gateway    drawing=off \
               --set wifi.public_ip  drawing=off \
               --set wifi.country    drawing=off
    return
  fi

  ROUTER="$(get_wifi_value "Router" <<<"$WIFI_INFO")"
  if [ -z "$ROUTER" ] || [ "$ROUTER" = "none" ]; then
    ROUTER="无网关"
  fi

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

  # All four rows go up in a single sketchybar call — the popup opens (in
  # click(), after this returns) with the final layout, no growth, no swap.
  sketchybar --set wifi.ip         drawing=on label="内网: $IP" \
             --set wifi.gateway    drawing=on label="网关: $ROUTER" \
             --set wifi.public_ip  drawing=on label="公网: $public_ip" \
             --set wifi.country    drawing=on label="地区: $country_label"
}

click() {
  DRAWING="$(sketchybar --query "$NAME" | jq -r '.popup.drawing')"
  if [ "$DRAWING" = "off" ]; then
    # Populate the rows *before* showing the popup, so the first visible
    # frame already has the final 4-row layout.
    set_details
    sketchybar --set "$NAME" popup.drawing=on
  else
    sketchybar --set "$NAME" popup.drawing=off
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
