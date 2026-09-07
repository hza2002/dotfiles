#!/bin/bash

[ "$SENDER" = "front_app_switched" ] || exit 0

APP_NAME="${INFO:-未知}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-sketchybar}"
LSAPPINFO_BIN="${LSAPPINFO_BIN:-/usr/bin/lsappinfo}"
GENERIC_APP_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"
FRONT_APP_NAME=""
FRONT_APP_BUNDLE_ID=""
FRONT_APP_PATH=""

read_front_app_from_lsappinfo() {
  local front_app app_info line bundle_id display_name bundle_path
  local fields_seen='|'
  local field_pattern='^"(CFBundleIdentifier|LSDisplayName|LSBundlePath)"="(.*)"$'

  front_app="$("$LSAPPINFO_BIN" front 2>/dev/null)" || return 1
  [ -n "$front_app" ] || return 1

  app_info="$("$LSAPPINFO_BIN" info -only bundleID,name,LSBundlePath "$front_app" 2>/dev/null)" || return 1
  # Keep the first occurrence, including empty values, as the old head -n 1 did.
  while IFS= read -r line; do
    [[ "$line" =~ $field_pattern ]] || continue
    [[ "$fields_seen" == *"|${BASH_REMATCH[1]}|"* ]] && continue
    fields_seen+="${BASH_REMATCH[1]}|"
    case "${BASH_REMATCH[1]}" in
      CFBundleIdentifier) bundle_id="${BASH_REMATCH[2]}" ;;
      LSDisplayName) display_name="${BASH_REMATCH[2]}" ;;
      LSBundlePath) bundle_path="${BASH_REMATCH[2]}" ;;
    esac
  done <<< "$app_info"

  FRONT_APP_BUNDLE_ID="${bundle_id:-}"
  [ -n "$FRONT_APP_BUNDLE_ID" ] || return 1

  FRONT_APP_NAME="${display_name:-}"
  FRONT_APP_PATH="${bundle_path:-}"
}

read_front_app_from_lsappinfo || true

case "$FRONT_APP_PATH" in
  *.app) APP_IMAGE="app.$FRONT_APP_BUNDLE_ID" ;;
  *) APP_IMAGE="$GENERIC_APP_ICON" ;;
esac

"$SKETCHYBAR_BIN" --set "$NAME" \
  label="${FRONT_APP_NAME:-$APP_NAME}" \
  icon="" \
  icon.background.drawing=on \
  icon.background.image="$APP_IMAGE"
