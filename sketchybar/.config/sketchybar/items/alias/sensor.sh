#!/bin/bash

source "$CONFIG_DIR/colors.sh"

SENSOR="iStat Menus Status,com.bjango.istatmenus.sensors"

sketchybar --add alias "$SENSOR" right \
           --set "$SENSOR" \
                 alias.color="$WHITE" \
                 alias.scale=0.9 \
                 padding_left=-3 \
                 padding_right=-5 \
                 background.color="$RED" \
                 background.corner_radius=4 \
                 background.height=24 \
                 background.padding_right=5 \
                 background.padding_left=3
