#!/bin/bash

# Apple logo click handler.
# Left  -> swiftDialog "About This Mac" panel built from fastfetch fields.
# Right -> toggle the popup (Preferences / Activity / Lock).

case "${BUTTON:-left}" in
left)
  DIALOG=$(command -v dialog || echo /usr/local/bin/dialog)
  if [ ! -x "$DIALOG" ]; then
    osascript -e 'display notification "swiftDialog 未安装: brew install --cask swiftdialog" with title "About"'
    exit 0
  fi

  # Force user's login shell so fastfetch reports the right one
  # (sketchybar may invoke plugins with SHELL=/bin/sh or bash).
  LOGIN_SHELL=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')
  : "${LOGIN_SHELL:=/bin/zsh}"

  FF=$(SHELL="$LOGIN_SHELL" /opt/homebrew/bin/fastfetch -l none --pipe 2>/dev/null |
    sed $'s/\x1b\\[[0-9;]*m//g')
  [ -z "$FF" ] && exit 0

  # Exact match: "Key: value"
  pick() { printf '%s' "$FF" | sed -n "s/^$1: //p" | head -1; }
  # Prefix match: "Key (anything): value"
  pick_prefix() { printf '%s' "$FF" | sed -n "s/^$1[^:]*: //p" | head -1; }

  HOST=$(pick "Host")
  OS=$(pick "OS")
  KERNEL=$(pick "Kernel")
  UPTIME=$(pick "Uptime")
  PACKAGES=$(pick "Packages")
  SHELL_VER=$(pick "Shell")
  DISPLAY_INFO=$(pick_prefix "Display")
  CPU=$(pick "CPU")
  GPU=$(pick "GPU")
  MEMORY=$(pick "Memory")
  SWAP=$(pick "Swap")
  DISK=$(printf '%s' "$FF" | sed -n 's|^Disk (/): ||p' | head -1)
  BATTERY=$(pick_prefix "Battery")
  POWER=$(pick "Power Adapter")
  LOCAL_IP=$(pick_prefix "Local IP")

  # Build one markdown row per external disk (may be 0..N).
  EXT_DISK_ROWS=""
  while IFS='|' read -r name usage; do
    [ -z "$name" ] && continue
    EXT_DISK_ROWS+="| $name | $usage |"$'\n'
  done < <(printf '%s' "$FF" | sed -n 's@^Disk (/Volumes/\([^)]*\)): \(.*\)@\1|\2@p')

  # Ordered to mirror fastfetch's own output sequence.
  MSG="| | |
| --- | --- |
| 设备 | ${HOST:-—} |
| 系统 | ${OS:-—} |
| 内核 | ${KERNEL:-—} |
| 运行时间 | ${UPTIME:-—} |
| 包数 | ${PACKAGES:-—} |
| Shell | ${SHELL_VER:-—} |
| 显示器 | ${DISPLAY_INFO:-—} |
| 芯片 | ${CPU:-—} |
| 显卡 | ${GPU:-—} |
| 内存 | ${MEMORY:-—} |
| 交换 | ${SWAP:-—} |
| 硬盘 | ${DISK:-—} |
${EXT_DISK_ROWS}| Local IP | ${LOCAL_IP:-—} |
| 电池 | ${BATTERY:-—} |
| 电源 | ${POWER:-—} |
"

  "$DIALOG" \
    --title "􀣺 关于本机" \
    --icon "none" \
    --message "$MSG" \
    --messagefont "name=JetBrains Maple Mono,size=12" \
    --button1text "好" \
    --width 500 \
    --height 640 \
    --moveable \
    --ontop \
    --position "center" \
    --quitkey "w" \
    >/dev/null 2>&1
  ;;
right | *)
  sketchybar --set apple.logo popup.drawing=toggle
  ;;
esac
