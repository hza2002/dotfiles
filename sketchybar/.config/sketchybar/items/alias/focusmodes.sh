#!/bin/bash

source "$CONFIG_DIR/colors.sh"

sketchybar --add alias "控制中心,FocusModes" right \
           --set "控制中心,FocusModes" \
                 padding_left=-5 \
                 padding_right=-22 \
                 alias.color="$WHITE" \
                 alias.scale=0.9
