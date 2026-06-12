#!/bin/bash

# Workaround for sketchybar bar going blank after display wake.
# Canonical community fix for FelixKratz/SketchyBar#497, #691, #783.
# Toggling the bar's display target forces window destroy/recreate so
# the rendering context is re-established after macOS wake.
WAKE_REFRESH_SCRIPT='sketchybar --bar display=main && sketchybar --bar display=all'

sketchybar --add item wake_refresh left                  \
           --set wake_refresh drawing=off                \
                              script="$WAKE_REFRESH_SCRIPT" \
           --subscribe wake_refresh system_woke
