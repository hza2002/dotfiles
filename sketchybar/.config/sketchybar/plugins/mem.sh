#!/usr/bin/env sh

source "$CONFIG_DIR/colors.sh"

# 获取系统内存剩余百分比
PERCENTAGE=$( memory_pressure | awk '/System-wide memory free percentage:/ { print 100 - $5 }')

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

COLOR=$RED
case ${PERCENTAGE} in
  8[0-9]|9[0-9]|100)  COLOR=$RED
  ;;
  [5-7][0-9])  COLOR=$ORANGE
  ;;
  [1-4][0-9])  COLOR=$GREEN
  ;;
  *)  COLOR=$GREY
esac

# 设置 SketchyBar 标签
sketchybar -m --set mem label="${PERCENTAGE}%" background.color="$COLOR"
