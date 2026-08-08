#!/bin/bash

# Caffeinate widget: idle shows ComputerName ("按点下班"),
# active shows infinity or HhMm countdown. Apple controls the display flag.
# Left click: toggle (off <-> forever).
# Right click: popup with duration presets + custom.

# Keep in sync with plugins/caffeinate.sh (IDLE_LABEL only).
IDLE_LABEL="按點下班"

caffeinate=(
  label="$IDLE_LABEL"
  label.font="$FONT_CN:Regular:20.0"
  label.color="$WHITE"
  label.padding_right=$PAD_WIDE
  padding_right=$PAD_ITEM
  padding_left=0
  icon.drawing=off
  background.drawing=off
  script="$PLUGIN_DIR/caffeinate.sh"
  click_script="$PLUGIN_DIR/caffeinate.sh click"
  update_freq=30
  popup.align=center
)

POPUP_OFF='sketchybar --set caffeinate popup.drawing=off'

caffeinate_suffix=(
  label.drawing=off
  icon.drawing=off
  background.drawing=off
  label.font="$FONT_MAIN:ExtraBold:15.0"
  label.color="$AQUA_SOFT"
  label.padding_right=$PAD_WIDE
  padding_left=0
  padding_right=$PAD_ITEM
)

caffeinate_1h=(
  icon="$CAFFEINATE_1H"
  label="1小时"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="$PLUGIN_DIR/caffeinate.sh hours 1; $POPUP_OFF"
)

caffeinate_3h=(
  icon="$CAFFEINATE_3H"
  label="3小时"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="$PLUGIN_DIR/caffeinate.sh hours 3; $POPUP_OFF"
)

caffeinate_6h=(
  icon="$CAFFEINATE_6H"
  label="6小时"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="$PLUGIN_DIR/caffeinate.sh hours 6; $POPUP_OFF"
)

caffeinate_until0=(
  icon="$CAFFEINATE_MIDNIGHT"
  label="晚上12点"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="$PLUGIN_DIR/caffeinate.sh until 00:00; $POPUP_OFF"
)

caffeinate_until10=(
  icon="$CAFFEINATE_NEXT_MORNING"
  label="次日10点"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="$PLUGIN_DIR/caffeinate.sh until +1d:10:00; $POPUP_OFF"
)

caffeinate_custom=(
  icon="$CAFFEINATE_CUSTOM"
  label="自定义…"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="$PLUGIN_DIR/caffeinate.sh custom; $POPUP_OFF"
)

sketchybar --add item caffeinate left \
  --set caffeinate "${caffeinate[@]}" \
  --subscribe caffeinate system_woke \
  \
  --add item caffeinate.suffix left \
  --set caffeinate.suffix "${caffeinate_suffix[@]}" \
  \
  --add item caffeinate.popup.1h popup.caffeinate \
  --set caffeinate.popup.1h "${caffeinate_1h[@]}" \
  \
  --add item caffeinate.popup.3h popup.caffeinate \
  --set caffeinate.popup.3h "${caffeinate_3h[@]}" \
  \
  --add item caffeinate.popup.6h popup.caffeinate \
  --set caffeinate.popup.6h "${caffeinate_6h[@]}" \
  \
  --add item caffeinate.popup.until0 popup.caffeinate \
  --set caffeinate.popup.until0 "${caffeinate_until0[@]}" \
  \
  --add item caffeinate.popup.until10 popup.caffeinate \
  --set caffeinate.popup.until10 "${caffeinate_until10[@]}" \
  \
  --add item caffeinate.popup.custom popup.caffeinate \
  --set caffeinate.popup.custom "${caffeinate_custom[@]}"
