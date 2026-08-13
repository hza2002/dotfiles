#!/bin/bash

WIDTH=100
SWITCH_AUDIO_SOURCE_BIN="${SWITCH_AUDIO_SOURCE_BIN:-SwitchAudioSource}"
SYSTEM_PROFILER_BIN="${SYSTEM_PROFILER_BIN:-/usr/sbin/system_profiler}"

volume_icon() {
  case "$1" in
    airpods) printf '%s\n' "$VOLUME_AIRPODS_PRO" ;;
    headphones|bluetooth_headphones) printf '%s\n' "$VOLUME_HEADPHONES" ;;
    bluetooth_speaker) printf '%s\n' "$VOLUME_SPEAKER" ;;
    display) printf '%s\n' "$VOLUME_DISPLAY" ;;
    usb) printf '%s\n' "$VOLUME_USB" ;;
    virtual) printf '%s\n' "$VOLUME_VIRTUAL" ;;
    *) return 1 ;;
  esac
}

bluetooth_device_class() {
  local uid="$1" profile_json="$2" address device

  address="${uid%:output}"
  address="${address//-/:}"
  address="$(printf '%s' "$address" | tr '[:upper:]' '[:lower:]')"
  device="$(printf '%s' "$profile_json" | jq -c --arg address "$address" '
    [.SPBluetoothDataType[]?.device_connected[]? | to_entries[] | .value
      | select((.device_address // "" | ascii_downcase) == $address)][0] // {}
  ' 2>/dev/null)"

  if printf '%s' "$device" | jq -e '
    .device_vendorID == "0x004C" and .device_minorType == "Headphones" and
    (has("device_batteryLevelCase") or has("device_batteryLevelLeft") or
     has("device_batteryLevelRight") or has("device_serialNumberLeft") or
     has("device_serialNumberRight"))
  ' >/dev/null 2>&1; then
    printf 'airpods\n'
    return
  fi

  case "$(printf '%s' "$device" | jq -r '.device_minorType // empty' 2>/dev/null)" in
    Headphones) printf 'bluetooth_headphones\n' ;;
    Speaker) printf 'bluetooth_speaker\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

device_class() {
  local uid="$1" name="$2" profile_json="$3" transport

  case "$uid" in
    BuiltInSpeakerDevice) printf 'speaker\n'; return ;;
    BuiltInHeadphoneOutputDevice) printf 'headphones\n'; return ;;
  esac

  transport="$(printf '%s' "$profile_json" | jq -r --arg name "$name" '
    [.SPAudioDataType[]?._items[]?
      | select(._name == $name and (.coreaudio_device_output // 0) > 0)
      | .coreaudio_device_transport][0] // empty
  ' 2>/dev/null)"

  case "$transport" in
    coreaudio_device_type_bluetooth) bluetooth_device_class "$uid" "$profile_json" ;;
    coreaudio_device_type_displayport|coreaudio_device_type_hdmi) printf 'display\n' ;;
    coreaudio_device_type_usb) printf 'usb\n' ;;
    coreaudio_device_type_virtual) printf 'virtual\n' ;;
    coreaudio_device_type_builtin)
      case "$uid" in
        *Headphone*) printf 'headphones\n' ;;
        *) printf 'speaker\n' ;;
      esac
      ;;
    *) printf 'unknown\n' ;;
  esac
}

current_output() {
  "$SWITCH_AUDIO_SOURCE_BIN" -c -t output -f json 2>/dev/null
}

valid_device_class() {
  case "$1" in
    airpods|headphones|bluetooth_headphones|bluetooth_speaker|display|speaker|usb|virtual|unknown) return 0 ;;
    *) return 1 ;;
  esac
}

write_device_cache() {
  local cache_dir="$1" cache_file="$2" uid="$3" class="$4" expires="$5" temp_file

  umask 077
  [ ! -L "$cache_dir" ] || return 1
  mkdir -p "$cache_dir" 2>/dev/null || return 1
  chmod 700 "$cache_dir" 2>/dev/null || return 1
  temp_file="$(mktemp "$cache_dir/volume-device.XXXXXX")" || return 1
  if printf '1\t%s\t%s\t%s\n' "$uid" "$class" "$expires" > "$temp_file" \
    && mv -f "$temp_file" "$cache_file" 2>/dev/null; then
    return 0
  fi
  rm -f "$temp_file" 2>/dev/null
  return 1
}

current_device_class() {
  local current current_after uid uid_after name profile_json class
  local cache_dir cache_file version cached_uid cached_class expires extra now ttl

  current="$(current_output)" || return 1
  uid="$(printf '%s' "$current" | jq -r '.uid // empty' 2>/dev/null)"
  name="$(printf '%s' "$current" | jq -r '.name // empty' 2>/dev/null)"
  [ -n "$uid" ] || return 1

  now="$(date +%s)"
  cache_dir="$HOME/Library/Caches/sketchybar"
  cache_file="$cache_dir/volume-device"
  if [ -f "$cache_file" ] \
    && IFS=$'\t' read -r version cached_uid cached_class expires extra < "$cache_file" \
    && [ "$version" = 1 ] \
    && [ "$cached_uid" = "$uid" ] \
    && valid_device_class "$cached_class" \
    && [[ "$expires" =~ ^[0-9]+$ ]] \
    && [ "$expires" -gt "$now" ] \
    && [ -z "${extra:-}" ]; then
    printf '%s\n' "$cached_class"
    return
  fi

  if profile_json="$("$SYSTEM_PROFILER_BIN" -timeout 2 SPAudioDataType SPBluetoothDataType -json 2>/dev/null)"; then
    class="$(device_class "$uid" "$name" "$profile_json")"
    valid_device_class "$class" || class=unknown
  else
    class=unknown
  fi

  current_after="$(current_output)" || return 1
  uid_after="$(printf '%s' "$current_after" | jq -r '.uid // empty' 2>/dev/null)"
  [ "$uid_after" = "$uid" ] || return 1

  [ "$class" = unknown ] && ttl=5 || ttl=21600
  write_device_cache "$cache_dir" "$cache_file" "$uid" "$class" "$((now + ttl))" || true
  printf '%s\n' "$class"
}

volume_change() {
  local device_icon
  source "$CONFIG_DIR/icons.sh"
  case $INFO in
    [6-9][0-9]|100) ICON=$VOLUME_100
    ;;
    [3-5][0-9]) ICON=$VOLUME_66
    ;;
    [1-2][0-9]) ICON=$VOLUME_33
    ;;
    [1-9]) ICON=$VOLUME_10
    ;;
    0) ICON=$VOLUME_0
    ;;
    *) ICON=$VOLUME_100
  esac

  device_icon="$(volume_icon "$(current_device_class 2>/dev/null)")" && ICON="$device_icon"

  sketchybar --set volume_icon icon="$ICON" \
             --set "$NAME" slider.percentage="$INFO"
}

mouse_clicked() {
  osascript -e "set volume output volume $PERCENTAGE"
}

mouse_entered() {
  sketchybar --set "$NAME" slider.knob.drawing=on
}

mouse_exited() {
  sketchybar --set "$NAME" slider.knob.drawing=off
}

case "$SENDER" in
  "test.device_class") device_class "$DEVICE_UID" "$DEVICE_NAME" "$DEVICE_PROFILE_JSON"
  ;;
  "test.current_device_class") current_device_class
  ;;
  "volume_change") volume_change
  ;;
  "mouse.clicked") mouse_clicked
  ;;
  "mouse.entered") mouse_entered
  ;;
  "mouse.exited") mouse_exited
  ;;
esac
