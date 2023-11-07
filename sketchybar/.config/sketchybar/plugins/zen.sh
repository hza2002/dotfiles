#!/bin/bash

zen_on() {
  sketchybar --set wifi drawing=off \
             --set apple.logo drawing=off \
             --set '/cpu.*/' drawing=off \
             --set calendar icon.drawing=off \
             --set separator drawing=off \
             --set front_app drawing=off \
             --set volume_icon drawing=off \
             --set spotify.anchor drawing=off \
             --set spotify.play updates=off \
             --set brew drawing=off \
             --set mem drawing=off \
             --set network_up drawing=off \
             --set network_down drawing=off \
             --set fortune drawing=off \
             --set system drawing=off \
             --set "iStat Menus Status,com.bjango.istatmenus.sensors" drawing=off \
             --set "iStat Menus Status,com.bjango.istatmenus.weather" drawing=off \
             --set "控制中心,FocusModes" drawing=off
}

zen_off() {
  sketchybar --set wifi drawing=on \
             --set apple.logo drawing=on \
             --set '/cpu.*/' drawing=on \
             --set calendar icon.drawing=on \
             --set separator drawing=on \
             --set front_app drawing=on \
             --set volume_icon drawing=on \
             --set spotify.play updates=on \
             --set brew drawing=on \
             --set mem drawing=on \
             --set network_up drawing=on \
             --set network_down drawing=on \
             --set fortune drawing=on \
             --set system drawing=on \
             --set "iStat Menus Status,com.bjango.istatmenus.sensors" drawing=on \
             --set "iStat Menus Status,com.bjango.istatmenus.weather" drawing=on \
             --set "控制中心,FocusModes" drawing=on
}

if [ "$1" = "on" ]; then
  zen_on
elif [ "$1" = "off" ]; then
  zen_off
else
  if [ "$(sketchybar --query apple.logo | jq -r ".geometry.drawing")" = "on" ]; then
    zen_on
  else
    zen_off
  fi
fi
