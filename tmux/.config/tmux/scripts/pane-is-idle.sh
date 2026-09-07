#!/bin/sh

# A failed or incomplete process snapshot must require confirmation.
set -eu
pane_pid=${1:?pane PID required}
pane_tty=${2:?pane TTY required}
case "$pane_pid" in ''|*[!0-9]*) exit 1 ;; esac
pane_tty=${pane_tty#/dev/}
processes=$(ps -ax -o pid= -o ppid= -o tty=) || exit 1
printf '%s\n' "$processes" | awk -v root="$pane_pid" -v tty="$pane_tty" '
  NF != 3 { invalid = 1; next }
  {
    if ($1 == root && $3 == tty) found = 1
    if ($1 != root && ($3 == tty || $2 == root)) busy = 1
  }
  END { exit !(found && !invalid && !busy) }
'
