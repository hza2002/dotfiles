#!/bin/bash

UPDOWN=$(ifstat -i "en0" -b 0.1 1 | tail -n1)
DOWN=$(echo "$UPDOWN" | awk "{ print \$1 }" | cut -f1 -d ".")
UP=$(echo "$UPDOWN" | awk "{ print \$2 }" | cut -f1 -d ".")

format_speed() {
    local speed=$1
    local formatted_speed

    if [ "$speed" -gt "999" ]; then
        formatted_speed="$(echo "$speed" | awk '{ printf "%.0f", $1 / 1000}') Mbps"
    else
        formatted_speed="${speed} kbps"
    fi

    printf "%6s" "$formatted_speed"
}

DOWN_FORMAT=$(format_speed "$DOWN")
UP_FORMAT=$(format_speed "$UP")

sketchybar -m --set network_down label="$DOWN_FORMAT"   label.align=right icon.highlight="$(if [ "$DOWN" -gt "0" ]; then echo "on"; else echo "off"; fi)" \
              --set network_up label="$UP_FORMAT"   label.align=right icon.highlight="$(if [ "$UP" -gt "0" ]; then echo "on"; else echo "off"; fi)"
