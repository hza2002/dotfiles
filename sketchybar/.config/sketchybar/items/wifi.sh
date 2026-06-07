#!/bin/bash

wifi=(
  padding_right=$PAD_ITEM
  label.width=0
  icon="$WIFI_DISCONNECTED"
  script="$PLUGIN_DIR/wifi.sh"
  icon.color=$BLUE_SOFT
  popup.align=center
  padding_right=$PAD_WIDE
)

wifi_ip=(
  icon.drawing=off
  label="内网: 未连接"
  label.width=dynamic
  label.align=center
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  script="$PLUGIN_DIR/wifi.sh"
)

wifi_gateway=(
  icon.drawing=off
  label="网关: 未连接"
  label.width=dynamic
  label.align=center
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  script="$PLUGIN_DIR/wifi.sh"
)

wifi_public_ip=(
  icon.drawing=off
  label="公网: 未连接"
  label.width=dynamic
  label.align=center
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  script="$PLUGIN_DIR/wifi.sh"
)

wifi_country=(
  icon.drawing=off
  label="地区: 未知"
  label.width=dynamic
  label.align=center
  padding_left=$PAD_WIDE
  padding_right=$PAD_WIDE
  script="$PLUGIN_DIR/wifi.sh"
)

sketchybar --add item wifi right                    \
           --set wifi "${wifi[@]}"                  \
           --subscribe wifi wifi_change             \
                            system_woke             \
                            mouse.clicked           \
                            mouse.exited.global     \
                                                         \
           --add item wifi.ip popup.wifi            \
           --set wifi.ip "${wifi_ip[@]}"            \
           --subscribe wifi.ip mouse.exited.global  \
                                                         \
           --add item wifi.gateway popup.wifi       \
           --set wifi.gateway "${wifi_gateway[@]}"  \
           --subscribe wifi.gateway mouse.exited.global \
                                                         \
           --add item wifi.public_ip popup.wifi     \
           --set wifi.public_ip "${wifi_public_ip[@]}" \
                                                         \
           --add item wifi.country popup.wifi       \
           --set wifi.country "${wifi_country[@]}"
