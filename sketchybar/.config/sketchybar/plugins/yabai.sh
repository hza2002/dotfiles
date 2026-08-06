#!/bin/bash

window_state() {
  source "$CONFIG_DIR/colors.sh"
  source "$CONFIG_DIR/icons.sh"

  WINDOW="$(yabai -m query --windows --window 2>/dev/null)" || return
  [ -n "$WINDOW" ] || return

  STATE="$(
    printf '%s' "$WINDOW" \
      | jq -r '[
          .["stack-index"] // 0,
          .["is-floating"] // false,
          .["has-fullscreen-zoom"] // false,
          .["has-parent-zoom"] // false
        ] | @tsv' 2>/dev/null
  )" || return
  [ -n "$STATE" ] || return
  IFS=$'\t' read -r STACK_INDEX IS_FLOATING HAS_FULLSCREEN_ZOOM HAS_PARENT_ZOOM <<< "$STATE"

  COLOR=$BAR_BORDER_COLOR
  ICON=""
  LABEL=""

  if [ "$IS_FLOATING" = "true" ]; then
    ICON+=$YABAI_FLOAT
    COLOR=$PURPLE
  elif [ "$HAS_FULLSCREEN_ZOOM" = "true" ]; then
    ICON+=$YABAI_FULLSCREEN_ZOOM
    COLOR=$GREEN
  elif [ "$HAS_PARENT_ZOOM" = "true" ]; then
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

space_windows_change() {
  local space="" value app count icon
  local icon_strip=" "
  local app_args=()
  local entry_count=0 total_count=0 i

  while IFS= read -r value; do
    if [ -z "$space" ]; then
      space="$value"
    elif [ -n "$value" ]; then
      entry_count=$((entry_count + 1))
      [ "$entry_count" -le 64 ] || return 0

      IFS=$'\t' read -r app count <<< "$value"
      case "$count" in
        0|[1-9]|1[0-6]) ;;
        *) return 0 ;;
      esac
      [ -n "$app" ] && [ "${#app}" -le 256 ] || return 0
      total_count=$((total_count + count))
      [ "$total_count" -le 64 ] || return 0

      for ((i = 0; i < count; i++)); do
        app_args+=("$app")
      done
    fi
  done < <(
    printf '%s' "$INFO" \
      | jq -r '
          .space,
          ((.apps // {})
            | if type == "object" then to_entries[] | [.key, .value] | @tsv
              else empty
              end)
        ' 2>/dev/null
  )

  case "$space" in
    [1-9]|[1-9][0-9]|1[01][0-9]|12[0-8]) ;;
    *) return 0 ;;
  esac

  if [ "${#app_args[@]}" -gt 0 ]; then
    while IFS= read -r icon; do
      icon_strip+=" $icon"
    done < <("$CONFIG_DIR"/plugins/icon_map.sh --batch "${app_args[@]}")
  fi

  sketchybar --set "space.$space" \
             label="$icon_strip" \
             label.drawing=on \
             background.drawing=on
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
  "space_windows_change") space_windows_change
  ;;
esac
