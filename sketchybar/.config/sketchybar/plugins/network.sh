#!/bin/bash

INTERFACE=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
UPDOWN=$(ifstat -i "${INTERFACE:-en0}" -b 0.1 1 | tail -n1)
DOWN=$(echo "$UPDOWN" | awk "{ print \$1 }" | cut -f1 -d ".")
UP=$(echo "$UPDOWN" | awk "{ print \$2 }" | cut -f1 -d ".")

sanitize_speed() {
    case "$1" in
        ''|*[!0-9]*) printf "0\n" ;;
        *) printf "%s\n" "$1" ;;
    esac
}

format_speed() {
    local speed
    speed=$(sanitize_speed "$1")

    if [ "$speed" -lt "8" ]; then
        printf "%s %s\n" "$speed" "kb/s"
    elif [ "$speed" -lt "8000" ]; then
        printf "%s %s\n" "$(echo "$speed" | awk '{ printf "%d", $1 / 8}')" "KB/s"
    else
        printf "%s %s\n" "$(echo "$speed" | awk '{ printf "%.1f", $1 / 8000}')" "MB/s"
    fi
}

DOWN=$(sanitize_speed "$DOWN")
UP=$(sanitize_speed "$UP")
read -r DOWN_VALUE DOWN_UNIT <<< "$(format_speed "$DOWN")"
read -r UP_VALUE UP_UNIT <<< "$(format_speed "$UP")"

sketchybar -m --set network_down label="$DOWN_VALUE" icon.highlight="$(if [ "$DOWN" -gt "0" ]; then echo "on"; else echo "off"; fi)" \
              --set network_down_unit label="$DOWN_UNIT" \
              --set network_up label="$UP_VALUE" icon.highlight="$(if [ "$UP" -gt "0" ]; then echo "on"; else echo "off"; fi)" \
              --set network_up_unit label="$UP_UNIT"
