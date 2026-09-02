#!/bin/sh

client_tty=$1
client_termname=$2
target_pane=$3
cursor_visible=$4
pane_left=$5
pane_top=$6
pane_width=$7
pane_height=$8
status_position=$9

[ "$client_termname" = xterm-ghostty ] || exit 0
[ "$cursor_visible" = 0 ] || exit 0

case "$pane_left:$pane_top:$pane_width:$pane_height" in
  *[!0-9:]*) exit 0 ;;
esac

case "$client_tty" in
  /dev/ttys[0-9]*|/dev/pts/[0-9]*) ;;
  *) exit 0 ;;
esac

[ -w "$client_tty" ] || exit 0

# tmux does not position the hardware cursor for a pane that hides it. Move to
# the pane center so consecutive cursorless panes give Ghostty distinct samples.
center_column=$((pane_left + pane_width / 2 + 1))
center_row=$((pane_top + pane_height / 2 + 1))
[ "$status_position" = top ] && center_row=$((center_row + 1))

# Wait for tmux to finish drawing, then expose the sample for two frames.
sleep 0.012
current_state=$(tmux display-message -p -c "$client_tty" \
  '#{pane_id}:#{cursor_flag}' 2>/dev/null) || exit 0
[ "$current_state" = "$target_pane:0" ] || exit 0

printf '\033[%d;%dH\033[?25h' "$center_row" "$center_column" >"$client_tty"
sleep 0.032

current_state=$(tmux display-message -p -c "$client_tty" \
  '#{pane_id}:#{cursor_flag}' 2>/dev/null) || {
  tmux refresh-client -t "$client_tty" >/dev/null 2>&1
  exit 0
}

# A later pane switch and its sample job own the terminal state now.
[ "$current_state" = "$target_pane:0" ] || exit 0
printf '\033[?25l' >"$client_tty"
tmux refresh-client -t "$client_tty" >/dev/null 2>&1
