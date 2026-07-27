#!/bin/bash

# CPU / MEM / TEMP / POWER share visuals and a mach helper data source.
# Order of registration controls right-to-left order in the bar.
add_system_widget() {
  local name=$1 icon=$2 icon_size=$3 label_size=$4 freq=$5
  local defaults=(
    icon="$icon"
    icon.font="$FONT_ICON:Bold:$icon_size"
    icon.padding_left=7
    label.font="$FONT_MAIN:Bold:$label_size"
    icon.color="$WHITE"
    label.color="$WHITE"
    background.height=26
    background.corner_radius=4
    label.padding_right=7
    update_freq="$freq"
  )
  $HELPER_AVAILABLE && defaults+=(mach_helper="$HELPER")
  sketchybar --add item "$name" right --set "$name" "${defaults[@]}"
}

add_system_widget fan "$SYS_FAN_STOP" 15 13 5
add_system_widget temp "$SYS_TEMP_MEDIUM" 15 13 5
add_system_widget power "$SYS_POWER_LOW" 15 13 3
add_system_widget mem "$SYS_MEM_LOW" 16 13 5
add_system_widget cpu "$SYS_CPU_LOW" 16 13 3

system_popup_row=(
  icon.font="$FONT_MAIN:Bold:13.0"
  icon.color="$GRAY_SOFT"
  icon.width=dynamic
  icon.align=left
  icon.padding_left=$PAD_WIDE
  icon.padding_right=4
  label.width=dynamic
  label.align=left
  label.padding_left=0
  label.padding_right=$PAD_WIDE
  label.max_chars=20
)

add_system_popup_row() {
  local parent=$1 name=$2 title=$3 initial=$4 drawing=${5:-on}
  sketchybar --add item "$name" "popup.$parent" \
             --set "$name" "${system_popup_row[@]}" \
                           icon="$title" label="$initial" \
                           drawing="$drawing"
}

configure_system_popup() {
  local name=$1
  sketchybar --set "$name" click_script="SENDER=mouse.clicked $PLUGIN_DIR/system_popup.sh" \
                           popup.align=center                                      \
                           popup.drawing=off
}

add_system_popup_row mem mem.pressure   "内存压力" "未知"
add_system_popup_row mem mem.total      "物理内存" "--.-GB"
add_system_popup_row mem mem.app        "应用内存" "--.-GB"
add_system_popup_row mem mem.wired      "系统固定" "--.-GB"
add_system_popup_row mem mem.compressed "内存压缩" "--.-GB"
add_system_popup_row mem mem.cached     "缓存文件" "--.-GB"
add_system_popup_row mem mem.swap       "磁盘交换" "--.-GB"

add_system_popup_row cpu cpu.user      "应用任务" "--%"
add_system_popup_row cpu cpu.system    "系统任务" "--%"
add_system_popup_row cpu cpu.process.1 "占用最高" "--"
add_system_popup_row cpu cpu.process.2 "占用第二" "--"
add_system_popup_row cpu cpu.process.3 "占用第三" "--"

add_system_popup_row temp temp.state "散热状态" "未知"
add_system_popup_row temp temp.max   "最高温度" "--°"

add_system_popup_row fan fan.1 "风扇一号" "--" off
add_system_popup_row fan fan.2 "风扇二号" "--" off
add_system_popup_row fan fan.3 "风扇三号" "--" off
add_system_popup_row fan fan.4 "风扇四号" "--" off

add_system_popup_row power power.adapter "适配器功率" "未知"

configure_system_popup mem
configure_system_popup cpu
configure_system_popup temp
configure_system_popup fan
configure_system_popup power
