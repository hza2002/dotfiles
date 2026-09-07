#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Toggle Internal Display
# @raycast.mode silent
# @raycast.icon internal-display.png
# @raycast.packageName 内屏控制
# @raycast.description 切换内屏自动控制：开启后连接外屏时关闭内屏，暂停后恢复内屏。

set -euo pipefail
binary="$HOME/.local/libexec/display-control"
[[ -x "$binary" ]] || { echo "Display Control is not installed"; exit 1; }
exec "$binary" toggle
