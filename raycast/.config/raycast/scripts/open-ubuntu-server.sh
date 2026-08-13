#!/bin/bash

set -euo pipefail

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Ubuntu Server
# @raycast.mode silent

# Optional parameters:
# @raycast.icon ghostty.png
# @raycast.packageName Remote
# @raycast.description Open the Ubuntu server in Ghostty and attach to tmux

readonly HOST="gpt"
readonly SESSION_NAME="main"
readonly SSH_TERM="xterm-256color"

/usr/bin/osascript - "$HOST" "$SESSION_NAME" "$SSH_TERM" <<'APPLESCRIPT'
on run argv
    set hostName to item 1 of argv
    set sessionName to item 2 of argv
    set termName to item 3 of argv
    set remoteCommand to "exec tmux new-session -A -s " & quoted form of sessionName
    set sshCommand to "/usr/bin/env TERM=" & quoted form of termName & " /usr/bin/ssh -t " & quoted form of hostName & " " & quoted form of remoteCommand

    tell application "Ghostty"
        set surfaceConfig to new surface configuration
        set command of surfaceConfig to sshCommand
        set wait after command of surfaceConfig to false
        set remoteWindow to new window with configuration surfaceConfig
        activate window remoteWindow
    end tell
end run
APPLESCRIPT
