#!/bin/bash

source "$CONFIG_DIR/colors.sh"

BATTERY="iStat Menus Menubar,com.bjango.istatmenus.battery"

sketchybar --add alias "$BATTERY" right \
           --set "$BATTERY" \
                 # alias.color="$WHITE" \
                 alias.scale=0.9 \
                 padding_left=-3 \
                 padding_right=-5 \
                 # background.color="$AQUA" \
                 background.corner_radius=4 \
                 background.height=24 \
                 background.padding_right=5 \
                 background.padding_left=3
