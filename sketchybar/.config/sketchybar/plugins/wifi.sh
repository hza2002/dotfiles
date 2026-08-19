#!/bin/bash

umask 077
CACHE_DIR="$HOME/Library/Caches/sketchybar"
CACHE_FILE="$CACHE_DIR/wifi-public.cache"
CACHE_LOCK="${CACHE_FILE}.lock"
CACHE_TTL=300  # 5 minutes

[ ! -L "$CACHE_DIR" ] || exit 1
mkdir -p "$CACHE_DIR" || exit 1
chmod 700 "$CACHE_DIR" || exit 1

cache_is_fresh() {
  local now cache_time

  [ -f "$CACHE_FILE" ] && [ ! -L "$CACHE_FILE" ] || return 1
  cache_time="$(stat -f %m "$CACHE_FILE" 2>/dev/null)" || return 1
  now="$(date +%s)"
  [ $((now - cache_time)) -lt $CACHE_TTL ]
}

fetch_public_info() {
  local result cache_tmp
  [ ! -e "$CACHE_FILE" ] || {
    [ -f "$CACHE_FILE" ] && [ ! -L "$CACHE_FILE" ] || return 1
  }
  result="$(curl -fsS --connect-timeout 3 --max-time 5 \
    'https://ipwho.is/?fields=success,ip,country,country_code' 2>/dev/null)"
  [ -n "$result" ] && [ "${#result}" -le 4096 ] || return 1
  result="$(printf '%s' "$result" \
    | jq -ce 'if type == "object" and .success == true
        and (.ip | type == "string")
        and (.country | type == "string")
        and (.country_code | type == "string")
      then {query: .ip, country: .country, countryCode: .country_code}
      else empty
      end' 2>/dev/null)" || return 1
  [ -n "$result" ] || return 1

  cache_tmp="$(mktemp "${CACHE_FILE}.XXXXXX")" || return 1
  if ! printf '%s\n' "$result" > "$cache_tmp"; then
    rm -f "$cache_tmp"
    return 1
  fi
  if ! mv -f "$cache_tmp" "$CACHE_FILE"; then
    rm -f "$cache_tmp"
    return 1
  fi
  printf '%s\n' "$result"
}

refresh_public_info() {
  cache_is_fresh && return
  exec 8>"$CACHE_LOCK" || return
  /usr/bin/lockf -t 0 8 2>/dev/null || {
    exec 8>&-
    return
  }
  (
    cache_is_fresh || fetch_public_info >/dev/null
  ) >/dev/null 2>&1 &
  exec 8>&-
}

get_public_info() {
  if [ -f "$CACHE_FILE" ] && [ ! -L "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    refresh_public_info
    return
  fi

  (
    exec 8>"$CACHE_LOCK" || exit
    /usr/bin/lockf -s -t 5 8 || exit
    if [ -f "$CACHE_FILE" ] && [ ! -L "$CACHE_FILE" ]; then
      cat "$CACHE_FILE"
    else
      fetch_public_info
    fi
  )
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

  # Pre-warm the public-IP cache without delaying the bar update.
  if [ -n "$IP" ]; then
    refresh_public_info
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

  # Display cached public info immediately and refresh stale data in the
  # background. Parse with one jq call instead of three Python processes.
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

case "$SENDER" in
  "wifi_change"|"system_woke"|"forced"|"routine") update
  ;;
  "mouse.clicked") click
  ;;
esac
