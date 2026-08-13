#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SOCKET="agent-sidebar-test-$$"

cleanup() {
  tmux -L "$SOCKET" kill-server 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

tmux -L "$SOCKET" -f /dev/null new-session -d -s test
socket_path="$(tmux -L "$SOCKET" display-message -p '#{socket_path}')"
window_id="$(tmux -L "$SOCKET" display-message -p '#{window_id}')"
normal_pane="$(tmux -L "$SOCKET" display-message -p '#{pane_id}')"
saved_layout="$(tmux -L "$SOCKET" display-message -p '#{window_layout}')"
sidebar_pane="$(tmux -L "$SOCKET" split-window -d -P -F '#{pane_id}')"
tmux -L "$SOCKET" set-option -p -t "$sidebar_pane" @pane_role sidebar
tmux -L "$SOCKET" set-option -w -t "$window_id" @agent_sidebar_saved_layout "$saved_layout"
tmux -L "$SOCKET" split-window -d

TMUX="$socket_path,99999,0" "$ROOT/scripts/agent-sidebar.sh" close "$window_id" "$normal_pane"

[ "$(tmux -L "$SOCKET" display-message -p -t "$window_id" '#{window_panes}')" = 2 ] \
  || fail "closing the sidebar removed a normal pane"
[ -z "$(tmux -L "$SOCKET" show-option -wqv -t "$window_id" @agent_sidebar_saved_layout)" ] \
  || fail "closing the sidebar retained stale layout state"

printf 'ok - topology changes do not break sidebar cleanup\n'
