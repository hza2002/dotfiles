#!/bin/bash

calendar=(
  icon="$LOADING"
  icon.font="$FONT_MAIN:ExtraBold:13.0"
  label.font="$FONT_MAIN:ExtraBold:13.0"
  label.width=dynamic
  label.align=right
  icon.padding_right=4
  padding_right=$PAD_ITEM
  update_freq=30
  mach_helper="$HELPER"
)

sketchybar --add item calendar right       \
           --set calendar "${calendar[@]}" \
           --subscribe calendar system_woke
