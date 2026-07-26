#!/bin/bash

# Workaround for sketchybar going blank after a real system wake.
# Canonical community fix for FelixKratz/SketchyBar#497, #97, #422.
# `system_woke` maps to NSWorkspace.didWakeNotification — it fires only on a
# genuine system wake. The handler toggles the bar display target to
# re-establish the rendering context; see plugins/wake_refresh.sh.
#
# NOTE: do NOT restart the service here — macOS re-delivers `system_woke` to the
# freshly-started process, causing an infinite restart loop.

sketchybar --add item wake_refresh left                  \
           --set wake_refresh drawing=off                \
                              updates=on                  \
                              script="$PLUGIN_DIR/wake_refresh.sh" \
           --subscribe wake_refresh system_woke
