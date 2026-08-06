#!/bin/sh

set -eu

saved_layout_option='@agent_sidebar_saved_layout'
saved_zoom_option='@agent_sidebar_saved_zoom'
return_pane_option='@agent_sidebar_return_pane'

find_sidebar() {
  tmux list-panes -t "$1" -F '#{pane_id}|#{@pane_role}' 2>/dev/null |
    awk -F '|' '$2 == "sidebar" { print $1; exit }'
}

clear_saved_layout() {
  tmux set-option -w -u -t "$1" "$saved_layout_option" 2>/dev/null || true
  tmux set-option -w -u -t "$1" "$saved_zoom_option" 2>/dev/null || true
}

close_sidebar() {
  window_id=$1
  current_pane=${2:-}
  sidebar_pane=$(find_sidebar "$window_id")

  if [ -z "$sidebar_pane" ]; then
    clear_saved_layout "$window_id"
    return
  fi

  saved_layout=$(tmux show-option -wqv -t "$window_id" "$saved_layout_option")
  saved_zoom=$(tmux show-option -wqv -t "$window_id" "$saved_zoom_option")
  return_pane=$(tmux show-option -pqv -t "$sidebar_pane" "$return_pane_option")
  target_pane=$current_pane
  if [ -z "$target_pane" ] || [ "$target_pane" = "$sidebar_pane" ]; then
    target_pane=$return_pane
  fi

  tmux kill-pane -t "$sidebar_pane"
  if [ -n "$saved_layout" ]; then
    tmux select-layout -t "$window_id" "$saved_layout" >/dev/null
  fi
  clear_saved_layout "$window_id"

  if [ -n "$target_pane" ] && tmux display-message -p -t "$target_pane" '#{pane_id}' >/dev/null 2>&1; then
    tmux select-pane -t "$target_pane"
    if [ "$saved_zoom" = '1' ]; then
      tmux resize-pane -Z -t "$target_pane"
    fi
  fi
}

toggle_sidebar() {
  window_id=$1
  current_pane=${2:-}
  if [ -n "$current_pane" ]; then
    pane_path=$(tmux display-message -p -t "$current_pane" '#{pane_current_path}' 2>/dev/null) || pane_path=$HOME
  else
    pane_path=$HOME
  fi
  [ -n "$pane_path" ] || pane_path=$HOME
  sidebar_pane=$(find_sidebar "$window_id")

  if [ -n "$sidebar_pane" ]; then
    if [ "$current_pane" = "$sidebar_pane" ]; then
      close_sidebar "$window_id" "$current_pane"
    else
      if [ -n "$current_pane" ]; then
        tmux set-option -p -t "$sidebar_pane" "$return_pane_option" "$current_pane"
      fi
      tmux select-pane -t "$sidebar_pane"
    fi
    return
  fi

  sidebar_bin=$(tmux show-option -gqv @agent_sidebar_bin)
  [ -n "$sidebar_bin" ] || exit 1

  saved_layout=$(tmux display-message -p -t "$window_id" '#{window_layout}')
  saved_zoom=$(tmux display-message -p -t "$window_id" '#{window_zoomed_flag}')
  tmux set-option -w -t "$window_id" "$saved_layout_option" "$saved_layout"
  tmux set-option -w -t "$window_id" "$saved_zoom_option" "$saved_zoom"

  "$sidebar_bin" toggle "$window_id" "$pane_path"
  sidebar_pane=$(find_sidebar "$window_id")
  if [ -z "$sidebar_pane" ]; then
    clear_saved_layout "$window_id"
    exit 1
  fi

  if [ -n "$current_pane" ]; then
    tmux set-option -p -t "$sidebar_pane" "$return_pane_option" "$current_pane"
  fi
  tmux select-pane -t "$sidebar_pane"
}

render_status() {
  tmux list-panes -a -F '#{@pane_agent}|#{@pane_status}|#{@pane_role}' 2>/dev/null |
    awk -F '|' '
      $3 != "sidebar" && ($1 == "claude" || $1 == "codex" || $1 == "opencode") {
        if ($2 == "running" || $2 == "background") running++
        else if ($2 == "idle") idle++
        else if ($2 == "waiting") waiting++
        else if ($2 == "error") error++
      }
      END {
        if (!(running || idle || waiting || error)) exit
        printf "#[fg=colour245] AI"
        if (running) printf " #[fg=colour114]●%d", running
        if (idle) printf " #[fg=colour110]✓%d", idle
        if (waiting) printf " #[fg=colour221]◐%d", waiting
        if (error) printf " #[fg=colour167]✕%d", error
        printf " #[default]"
      }
    '
}

case ${1:-} in
  toggle) toggle_sidebar "${2:?window id required}" "${3:-}" ;;
  close) close_sidebar "${2:?window id required}" "${3:-}" ;;
  status) render_status ;;
  *) exit 2 ;;
esac
