#!/bin/bash

volume_slider=(
  script="$PLUGIN_DIR/volume.sh"
  updates=on
  padding_left=0
  padding_right=0
  label.drawing=off
  icon.drawing=off
  slider.highlight_color="$BLUE"
  slider.background.height=5
  slider.background.corner_radius=3
  slider.background.color="$BACKGROUND_2"
  slider.knob=􀀁
  slider.knob.drawing=off
)

volume_icon=(
  script="$PLUGIN_DIR/volume_click.sh"
  padding_left=6
  padding_right=0
  label.drawing=off
  icon="$VOLUME_100"
  icon.align=left
  icon.color="$WHITE"
  icon.font="$FONT:Regular:14.0"
  popup.align=center
)

status_bracket=(
  background.color="$BACKGROUND_1"
  background.border_color="$BACKGROUND_2"
  background.border_width=2
  background.height=28
)

status_padding=(
  width="$GROUP_PADDINGS"
  label.drawing=off
  icon.drawing=off
)

sketchybar --add slider volume right            \
           --set volume "${volume_slider[@]}"   \
           --subscribe volume volume_change     \
                              mouse.clicked     \
                              mouse.entered     \
                              mouse.exited      \
                                                \
           --add item volume_icon right         \
           --set volume_icon "${volume_icon[@]}" \
           --subscribe volume_icon mouse.clicked \
                                    mouse.scrolled \
                                    mouse.exited.global

sketchybar --add bracket status network_up_unit network_down_unit network_up network_down wifi volume volume_icon \
           --set status "${status_bracket[@]}" \
           --add item status.padding right     \
           --set status.padding "${status_padding[@]}"
