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
  local front_app app_info

  front_app="$("$LSAPPINFO_BIN" front 2>/dev/null)" || return 1
  [ -n "$front_app" ] || return 1

  app_info="$("$LSAPPINFO_BIN" info -only bundleID,name,LSBundlePath "$front_app" 2>/dev/null)" || return 1
  FRONT_APP_BUNDLE_ID="$(printf '%s\n' "$app_info" | sed -n 's/^"CFBundleIdentifier"="\(.*\)"$/\1/p' | head -n 1)"
  [ -n "$FRONT_APP_BUNDLE_ID" ] || return 1

  FRONT_APP_NAME="$(printf '%s\n' "$app_info" | sed -n 's/^"LSDisplayName"="\(.*\)"$/\1/p' | head -n 1)"
  FRONT_APP_PATH="$(printf '%s\n' "$app_info" | sed -n 's/^"LSBundlePath"="\(.*\)"$/\1/p' | head -n 1)"
}

resolve_app_image() {
  case "$FRONT_APP_PATH" in
    *.app)
    printf 'app.%s\n' "$FRONT_APP_BUNDLE_ID"
    return
    ;;
  esac

  printf '%s\n' "$GENERIC_APP_ICON"
}

read_front_app_from_lsappinfo || true

"$SKETCHYBAR_BIN" --set "$NAME" \
  label="${FRONT_APP_NAME:-$APP_NAME}" \
  icon="" \
  icon.background.drawing=on \
  icon.background.image="$(resolve_app_image)"
