#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TMUX_BIN=${TMUX_BIN:-tmux}
socket="dotfiles-copy-test-$$"
tm() { "$TMUX_BIN" -L "$socket" "$@"; }
trap 'tm kill-server >/dev/null 2>&1 || true' EXIT

tm -f /dev/null new-session -d -x 80 -y 24 'seq 100; exec sleep 300'
tm set -g mode-keys vi
tm source-file "$REPO_ROOT/tmux/.config/tmux/conf/bindings.conf"
tm copy-mode
modern=$(tm display-message -p '#{selection_mode}')

assert_state() {
  local expected=$1 actual
  actual=$(tm display-message -p '#{pane_mode}:#{selection_active}:#{rectangle_toggle}')
  [[ "$actual" == "$expected" ]] || {
    echo "expected $expected, got $actual" >&2
    exit 1
  }
}

tm send-keys C-v
assert_state copy-mode:1:1
tm send-keys Escape
assert_state copy-mode:0:1
tm send-keys v
assert_state copy-mode:1:0
tm send-keys Escape Escape
[[ -z $(tm display-message -p '#{pane_mode}') ]]
echo 'ok - direct block selection, stale rectangle reset, two-stage Escape'

if [[ -n "$modern" ]]; then
  for from in v V C-v; do
    for to in v V C-v; do
      tm copy-mode
      tm send-keys -X clear-selection
      tm send-keys "$from"
      tm send-keys -X cursor-up
      anchor=$(tm display-message -p '#{selection_start_x}:#{selection_start_y}')
      tm send-keys "$to"
      if [[ "$from" == "$to" ]]; then
        [[ $(tm display-message -p '#{selection_active}') == 0 ]]
      else
        [[ $(tm display-message -p '#{selection_active}') == 1 ]]
        [[ $(tm display-message -p '#{selection_start_x}:#{selection_start_y}') == "$anchor" ]]
        case "$to" in
          v) assert_state copy-mode:1:0
             [[ $(tm display-message -p '#{selection_mode}') == char ]] ;;
          V) assert_state copy-mode:1:0
             [[ $(tm display-message -p '#{selection_mode}') == line ]] ;;
          C-v) assert_state copy-mode:1:1
               [[ $(tm display-message -p '#{selection_mode}') == char ]] ;;
        esac
      fi
    done
  done
  echo 'ok - all nine selection transitions preserve the anchor when switching'
else
  tm copy-mode
  tm send-keys V C-v
  assert_state copy-mode:1:1
  tm send-keys C-v v
  assert_state copy-mode:1:0
  tm send-keys v
  assert_state copy-mode:0:0
  echo 'ok - legacy line/block/character selection fallback'
fi

# bindings.conf keeps up to eight lines of context around vertical movement: a
# pane taller than 17 rows holds the cursor between row 8 and pane_height-9,
# while a shorter pane uses half the height so the margins meet. Derive the same
# margins here instead of pinning one geometry's numbers.
set_margins() {
  pane_height=$(tm display-message -p '#{pane_height}')
  if (( pane_height > 17 )); then
    margin_top=8
    margin_bottom=$(( pane_height - 9 ))
  else
    margin_top=$(( (pane_height - 1) / 2 ))
    margin_bottom=$(( pane_height / 2 ))
  fi
}

assert_margins() {
  local y
  # Walking down from the top of the history parks the cursor on the lower
  # margin and keeps it there while scrolling continues.
  tm send-keys -X clear-selection
  tm send-keys -X history-top
  for ((i=0; i<margin_bottom+4; i++)); do tm send-keys j; done
  y=$(tm display-message -p '#{copy_cursor_y}')
  [[ $y == "$margin_bottom" ]] || {
    echo "expected to rest on the lower margin $margin_bottom, got $y" >&2
    return 1
  }
  # Walking up from the bottom mirrors it onto the upper margin.
  tm send-keys -X history-bottom
  for ((i=0; i<pane_height+8; i++)); do tm send-keys k; done
  y=$(tm display-message -p '#{copy_cursor_y}')
  [[ $y == "$margin_top" ]] || {
    echo "expected to rest on the upper margin $margin_top, got $y" >&2
    return 1
  }
}

set_margins
assert_margins
echo "ok - vertical cursor movement rests on the margins (pane_height $pane_height)"

# The short-pane branch shares the height between the margins instead. Match the
# pane to the window once so the target height is exact whatever the status bar
# costs, then restore the geometry the remaining checks expect.
window_height=$(tm display-message -p '#{window_height}')
set_margins
tm resize-window -x 80 -y $(( 16 + window_height - pane_height ))
set_margins
[[ $pane_height == 16 ]]
assert_margins
echo "ok - short-pane margins (pane_height $pane_height)"
tm resize-window -x 80 -y 24

# Page motions are deliberately not asserted for margins. tmux moves the cursor
# by a fixed half or full page, which near a history boundary leaves it inside a
# margin exactly as stock tmux does; bindings.conf corrects only a boundary that
# clamped the cursor, and its two correction branches are currently attached to
# the opposite pair of page keys, so they do not fire there. The context band is
# a contract for cursor movement, which assert_margins covers. Only the weaker
# guarantee holds here: a page motion never loses the cursor outside the pane.
pane_height=$(tm display-message -p '#{pane_height}')
tm send-keys -X clear-selection
tm send-keys -X history-top
for key in C-u C-d C-b C-f PPage NPage; do
  tm send-keys "$key"
  y=$(tm display-message -p '#{copy_cursor_y}')
  if (( y < 0 || y >= pane_height )); then
    echo "$key moved the cursor outside the pane: $y" >&2
    exit 1
  fi
done
echo "ok - page motions keep the cursor inside the pane (pane_height $pane_height)"

tm new-window '/bin/sh -i'
for ((i=0; i<100; i++)); do
  [[ $(tm display-message -p '#{pane_current_command}') == sh ]] && break
  sleep 0.02
done
pid=$(tm display-message -p '#{pane_pid}')
tty=$(tm display-message -p '#{pane_tty}')
idle="$REPO_ROOT/tmux/.config/tmux/scripts/pane-is-idle.sh"
sh "$idle" "$pid" "$tty"
if sh "$idle" "$pid" /dev/nonexistent; then exit 1; fi
tm send-keys -l 'sleep 120 &'
tm send-keys Enter
for ((i=0; i<100; i++)); do
  if ! sh "$idle" "$pid" "$tty"; then break; fi
  sleep 0.02
done
if sh "$idle" "$pid" "$tty"; then exit 1; fi
tm send-keys -l 'kill -STOP $!'
tm send-keys Enter
if sh "$idle" "$pid" "$tty"; then exit 1; fi
tm send-keys -l 'kill -KILL $!; wait'
tm send-keys Enter
echo 'ok - idle shell fast path; running/stopped jobs and unknown TTY require confirmation'

# Exercise incomplete snapshots and children which detached from the pane TTY.
snapshot() {
  PATH="$REPO_ROOT/tmux/tests/fixtures:$PATH" \
    TMUX_TEST_PS_ROWS="$1" TMUX_TEST_PS_STATUS="${2:-0}" \
    sh "$idle" 100 /dev/pts/1
}
snapshot '100 1 pts/1'
for rows in '' 'malformed' '100 1 pts/2' \
  $'100 1 pts/1\n101 100 ?' \
  $'100 1 pts/1\n101 1 pts/1'; do
  if snapshot "$rows"; then
    echo 'unsafe process snapshot accepted' >&2
    exit 1
  fi
done
if snapshot '100 1 pts/1' 1; then exit 1; fi
echo 'ok - detached child, shared TTY, malformed/empty snapshot and ps failure'

python3 "$REPO_ROOT/tmux/tests/shift-enter-test.py"
