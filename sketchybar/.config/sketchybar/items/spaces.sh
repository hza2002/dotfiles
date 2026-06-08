#!/bin/bash

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9")

# Destroy space on right click, focus space on left click.
# New space by left clicking separator (>)

sid=0
for i in "${!SPACE_ICONS[@]}"
do
  sid=$(($i+1))

  space=(
    associated_space="$sid"
    icon="${SPACE_ICONS[i]}"
    icon.padding_left=10
    icon.padding_right=0
    padding_left=2
    padding_right=2
    label.padding_right=20
    icon.highlight_color="$ORANGE_SOFT"
    label.color="$GRAY"
    label.highlight_color="$WHITE"
    label.font="sketchybar-app-font:Regular:16.0"
    label.y_offset=-1
    background.color="$BACKGROUND_1"
    background.border_color="$BACKGROUND_2"
    background.border_width=0
    background.height=23
    popup.background.border_width=5
    popup.background.border_color="$BLACK"
    script="$PLUGIN_DIR/space.sh"
  )

  space_popup=(
    padding_left=5
    padding_right=0
    icon.drawing=off
    label.drawing=off
    background.drawing=on
    background.image.corner_radius=9
    background.image.scale=0.2
  )

  space_bracket=(
    background.color="$TRANSPARENT"
    background.border_color="$BACKGROUND_2"
    background.border_width="$BD"
    background.height="$BR_H"
  )

  space_padding=(
    associated_space="$sid"
    width=4
    icon.drawing=off
    label.drawing=off
    background.drawing=off
    script=""
  )

  sketchybar --add space space.$sid left            \
             --set space.$sid "${space[@]}"         \
             --subscribe space.$sid mouse.clicked   \
                                  mouse.exited      \
             --add item space.$sid.preview popup.space.$sid \
             --set space.$sid.preview "${space_popup[@]}" \
             --add bracket space.$sid.bracket space.$sid \
             --set space.$sid.bracket "${space_bracket[@]}" \
             --add space space.$sid.padding left     \
             --set space.$sid.padding "${space_padding[@]}"
done

spaces_padding=(
  width=5
  label.drawing=off
  icon.drawing=off
)

separator=(
  icon=$SPACE_SEPARATOR
  icon.font="$FONT_ICON:Heavy:16.0"
  padding_left=10
  padding_right=8
  label.drawing=off
  associated_display=active
  click_script='yabai -m space --create && sketchybar --trigger space_change'
  icon.color="$ORANGE_SOFT"
)

sketchybar --add item spaces.padding left              \
           --set spaces.padding "${spaces_padding[@]}" \
           --add item separator left                   \
           --set separator "${separator[@]}"
