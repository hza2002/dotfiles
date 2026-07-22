#!/bin/bash

update() {
  source "$CONFIG_DIR/colors.sh"
  COLOR=$BACKGROUND_2
  if [ "$SELECTED" = "true" ]; then
    COLOR=$RED
  fi
  sketchybar --set "$NAME" icon.highlight="$SELECTED" \
                         label.highlight="$SELECTED" \
                         background.border_color=$COLOR \
             --set "$NAME.bracket" background.border_color="$COLOR"
}

toggle_preview() {
  sketchybar --set "$NAME.preview" background.image="$NAME" \
             --set "$NAME" popup.drawing=toggle
}

mouse_clicked() {
  if [ "$BUTTON" = "right" ]; then
    yabai -m space --destroy "$SID"
    sketchybar --trigger windows_on_spaces --trigger space_change
  else
    if [ "$MODIFIER" = "cmd" ] || [ "$MODIFIER" = "command" ]; then
      toggle_preview
    else
      yabai -m space --focus "$SID" 2>/dev/null
    fi
  fi
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  "mouse.exited") sketchybar --set "$NAME" popup.drawing=off
  ;;
  *) update
  ;;
esac
