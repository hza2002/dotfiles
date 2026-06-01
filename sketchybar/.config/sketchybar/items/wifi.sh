#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

wifi=(
  padding_left=0
  padding_right=9
  label.width=0
  icon="$WIFI_DISCONNECTED"
  script="$PLUGIN_DIR/wifi.sh"
  icon.color=$BLUE_SOFT
  popup.align=center
)

wifi_ip=(
  icon.drawing=off
  label="IP: 未连接"
  label.width=dynamic
  label.align=center
  label.padding_left=10
  label.padding_right=10
  script="$PLUGIN_DIR/wifi.sh"
)

wifi_gateway=(
  icon.drawing=off
  label="网关: 未连接"
  label.width=dynamic
  label.align=center
  label.padding_left=10
  label.padding_right=10
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
           --subscribe wifi.gateway mouse.exited.global
