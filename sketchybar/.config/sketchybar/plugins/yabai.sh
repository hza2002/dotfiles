#!/bin/bash

window_state() {
  source "$CONFIG_DIR/colors.sh"
  source "$CONFIG_DIR/icons.sh"

  WINDOW="$(yabai -m query --windows --window 2>/dev/null)" || return
  [ -n "$WINDOW" ] || return

  STACK_INDEX="$(printf '%s' "$WINDOW" | jq -r '.["stack-index"] // 0' 2>/dev/null)" || return

  COLOR=$BAR_BORDER_COLOR
  ICON=""

  if [ "$(printf '%s' "$WINDOW" | jq -r '.["is-floating"] // false' 2>/dev/null)" = "true" ]; then
    ICON+=$YABAI_FLOAT
    COLOR=$PURPLE
  elif [ "$(printf '%s' "$WINDOW" | jq -r '.["has-fullscreen-zoom"] // false' 2>/dev/null)" = "true" ]; then
    ICON+=$YABAI_FULLSCREEN_ZOOM
    COLOR=$GREEN
  elif [ "$(printf '%s' "$WINDOW" | jq -r '.["has-parent-zoom"] // false' 2>/dev/null)" = "true" ]; then
    ICON+=$YABAI_PARENT_ZOOM
    COLOR=$BLUE
  elif [[ $STACK_INDEX -gt 0 ]]; then
    LAST_STACK_INDEX="$(yabai -m query --windows --window stack.last 2>/dev/null | jq -r '.["stack-index"] // 0' 2>/dev/null)"
    ICON+=$YABAI_STACK
    LABEL="$(printf "[%s/%s]" "$STACK_INDEX" "$LAST_STACK_INDEX")"
    COLOR=$RED
  fi

  args=(--animate sin 10 --bar border_color="$COLOR"
                         --set "$NAME" icon.color="$COLOR")

  [ -z "$LABEL" ] && args+=(label.width=0) \
                  || args+=(label="$LABEL" label.width=40)

  [ -z "$ICON" ] && args+=(icon.width=0) \
                 || args+=(icon="$ICON" icon.width=30)

  sketchybar "${args[@]}"
}

windows_on_spaces () {
  # Query all windows + spaces once, then group locally (avoids N+1 yabai IPC).
  WINDOWS="$(yabai -m query --windows 2>/dev/null)" || return
  SPACES="$(yabai -m query --spaces 2>/dev/null | jq -r '.[].index' 2>/dev/null)" || return
  [ -n "$SPACES" ] || return

  args=(--animate sin 10)

  for space in $SPACES
  do
    icon_strip=" "
    apps=$(printf '%s' "$WINDOWS" | jq -r --argjson s "$space" \
      '.[] | select(.space == $s and .role == "AXWindow" and ."has-ax-reference" == true and ."is-minimized" == false and ."is-hidden" == false) | .app' 2>/dev/null)
    if [ -n "$apps" ]; then
      app_args=()
      while IFS= read -r app; do
        [ -n "$app" ] && app_args+=("$app")
      done <<< "$apps"
      while IFS= read -r icon; do
        icon_strip+=" $icon"
      done < <("$CONFIG_DIR"/plugins/icon_map.sh --batch "${app_args[@]}")
    fi
    args+=(--set space."$space" label="$icon_strip" label.drawing=on background.drawing=on)
  done

  sketchybar "${args[@]}"
}

mouse_clicked() {
  yabai -m window --toggle float >/dev/null 2>&1 || return
  window_state
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  "forced") exit 0
  ;;
  "window_focus") window_state 
  ;;
  "windows_on_spaces" | "space_change") windows_on_spaces
  ;;
esac
