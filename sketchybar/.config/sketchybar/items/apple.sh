#!/bin/bash

POPUP_OFF='sketchybar --set apple.logo popup.drawing=off'

apple_logo=(
  icon=$APPLE
  icon.font="$FONT_ICON:Black:16.0"
  icon.color=0xfffbf1c7
  padding_left=$PAD_ITEM
  padding_right=$PAD_WIDE
  label.drawing=off
  click_script="$PLUGIN_DIR/apple.sh click"
)

apple_about=(
  icon=$APPLE
  label="About This Mac"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="$POPUP_OFF; $PLUGIN_DIR/apple.sh about"
)

apple_prefs=(
  icon=$PREFERENCES
  label="Preferences"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="open -a 'System Settings'; $POPUP_OFF"
)

apple_activity=(
  icon=$ACTIVITY
  label="Activity"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="open -a 'Activity Monitor'; $POPUP_OFF"
)

apple_lock=(
  icon=$LOCK
  label="关闭显示器"
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  click_script="$PLUGIN_DIR/caffeinate.sh display-sleep"
)

sketchybar --add item apple.logo left                  \
           --set apple.logo "${apple_logo[@]}"         \
                                                       \
           --add item apple.about popup.apple.logo     \
           --set apple.about "${apple_about[@]}"       \
                                                       \
           --add item apple.prefs popup.apple.logo     \
           --set apple.prefs "${apple_prefs[@]}"       \
                                                       \
           --add item apple.activity popup.apple.logo  \
           --set apple.activity "${apple_activity[@]}" \
                                                       \
           --add item apple.lock popup.apple.logo      \
           --set apple.lock "${apple_lock[@]}"
