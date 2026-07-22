#!/bin/bash

# Handler for the `system_woke` event (fires only on real system wake, i.e.
# NSWorkspace.didWakeNotification — not on pure lock/screensaver/display-sleep).
#
# Known-good surface repair: toggling the bar's display target forces a window
# destroy/recreate so the rendering context is re-established after wake.
sketchybar --bar display=main && sketchybar --bar display=all
