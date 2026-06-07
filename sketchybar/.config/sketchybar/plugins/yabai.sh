#!/bin/bash

window_state() {
  source "$CONFIG_DIR/colors.sh"
  source "$CONFIG_DIR/icons.sh"

  WINDOW=$(yabai -m query --windows --window)
  STACK_INDEX=$(echo "$WINDOW" | jq '.["stack-index"]')

  COLOR=$BAR_BORDER_COLOR
  ICON=""

  if [ "$(echo "$WINDOW" | jq '.["is-floating"]')" = "true" ]; then
    ICON+=$YABAI_FLOAT
    COLOR=$PURPLE
  elif [ "$(echo "$WINDOW" | jq '.["has-fullscreen-zoom"]')" = "true" ]; then
    ICON+=$YABAI_FULLSCREEN_ZOOM
    COLOR=$GREEN
  elif [ "$(echo "$WINDOW" | jq '.["has-parent-zoom"]')" = "true" ]; then
    ICON+=$YABAI_PARENT_ZOOM
    COLOR=$BLUE
  elif [[ $STACK_INDEX -gt 0 ]]; then
    LAST_STACK_INDEX=$(yabai -m query --windows --window stack.last | jq '.["stack-index"]')
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
  if [ "$SENDER" = "space_windows_change" ] && [ -n "$INFO" ]; then
    space="$(echo "$INFO" | jq -r '.space // empty' 2>/dev/null)"
    if [[ "$space" =~ ^[1-9][0-9]*$ ]]; then
      icon_strip=" "
      apps="$(echo "$INFO" | jq -r '.apps | to_entries[]? | .key as $app | range(.value) | $app' 2>/dev/null)"
      if [ -n "$apps" ]; then
        app_args=()
        while IFS= read -r app; do
          [ -n "$app" ] && app_args+=("$app")
        done <<< "$apps"
        while IFS= read -r icon; do
          icon_strip+=" $icon"
        done < <("$CONFIG_DIR"/plugins/icon_map.sh --batch "${app_args[@]}")
      else
        icon_strip=" —"
      fi

      sketchybar --animate sin 10 --set space."$space" label="$icon_strip" label.drawing=on
      return
    fi
  fi

  CURRENT_SPACES="$(yabai -m query --displays | jq -r '.[].spaces | @sh')"

  args=(--animate sin 10)

  while read -r line
  do
    for space in $line
    do
      icon_strip=" "
      apps=$(yabai -m query --windows --space "$space" | jq -r ".[].app")
      if [ "$apps" != "" ]; then
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
  done <<< "$CURRENT_SPACES"

  sketchybar "${args[@]}"
}

mouse_clicked() {
  yabai -m window --toggle float
  window_state
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  "forced") exit 0
  ;;
  "window_focus") window_state 
  ;;
  "windows_on_spaces" | "space_windows_change") windows_on_spaces
  ;;
esac
