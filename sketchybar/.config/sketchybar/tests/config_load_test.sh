#!/bin/bash
set -eu

SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-config-test.XXXXXX")"
CONFIG_ROOT="$TEST_ROOT/config"
FAKE_BIN="$TEST_ROOT/bin"
TEST_HOME="$TEST_ROOT/home"
CALLS="$TEST_ROOT/calls"
NOTICES="$TEST_ROOT/notices"

cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

mkdir -p "$CONFIG_ROOT/items" "$CONFIG_ROOT/helper" "$FAKE_BIN" "$TEST_HOME"
cp "$SOURCE_ROOT/sketchybarrc" "$CONFIG_ROOT/sketchybarrc"
: >"$CONFIG_ROOT/colors.sh"
: >"$CONFIG_ROOT/icons.sh"
: >"$CONFIG_ROOT/spacing.sh"

for item in apple caffeinate spaces yabai front_app calendar wifi network battery volume system; do
  : >"$CONFIG_ROOT/items/$item.sh"
done
printf 'printf "later-item-loaded\\n" >>"$CONFIG_TEST_CALLS"\n' \
  >"$CONFIG_ROOT/items/system.sh"

cat >"$FAKE_BIN/sketchybar" <<'SH'
#!/bin/bash
printf 'sketchybar %s\n' "$*" >>"$CONFIG_TEST_CALLS"
if [ "${CONFIG_TEST_FAIL_DEFAULT:-0}" = 1 ] && [ "${1:-}" = --default ]; then
  printf 'rejected default options\n' >&2
  exit 23
fi
SH

cat >"$FAKE_BIN/launchctl" <<'SH'
#!/bin/bash
exit 0
SH

cat >"$FAKE_BIN/osascript" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$CONFIG_TEST_NOTICES"
SH

cat >"$CONFIG_ROOT/helper/start.sh" <<'SH'
#!/bin/bash
if [ "${CONFIG_TEST_FAIL_HELPER:-0}" = 1 ]; then
  printf 'helper start failed\n' >&2
  exit 17
fi
SH

chmod +x "$FAKE_BIN"/* "$CONFIG_ROOT/helper/start.sh" "$CONFIG_ROOT/sketchybarrc"

run_config() {
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_HOME" BAR_NAME=sketchybar \
    CONFIG_DIR="$CONFIG_ROOT" CONFIG_TEST_CALLS="$CALLS" \
    CONFIG_TEST_NOTICES="$NOTICES" CONFIG_TEST_FAIL_DEFAULT="${1:-0}" \
    CONFIG_TEST_FAIL_HELPER="${2:-0}" /bin/bash "$CONFIG_ROOT/sketchybarrc"
}

: >"$CALLS"
: >"$NOTICES"
run_config 1 0 || fail "a rejected item command aborted config loading"
grep -q '^later-item-loaded$' "$CALLS" || fail "later items were not loaded"
grep -q '^sketchybar --update$' "$CALLS" || fail "final update was skipped"
[ "$(wc -l <"$NOTICES" | tr -d ' ')" = 1 ] || fail "command error did not send one notice"
CONFIG_LOG="$TEST_HOME/Library/Logs/sketchybar/config.log"
grep -q 'event=command_failed rc=23 command=--default' "$CONFIG_LOG" \
  || fail "command error was not written to config log"
[ "$(stat -f %Lp "$CONFIG_LOG")" = 600 ] || fail "config log is not private"
printf 'ok - command errors are logged without aborting later items\n'

: >"$CALLS"
: >"$NOTICES"
printf 'return 29\n' >"$CONFIG_ROOT/items/spaces.sh"
run_config 0 0 || fail "an item source failure aborted config loading"
grep -q '^later-item-loaded$' "$CALLS" || fail "source failure blocked later items"
[ "$(wc -l <"$NOTICES" | tr -d ' ')" = 1 ] || fail "source error did not send one notice"
grep -q 'event=source_failed rc=29 file=.*/items/spaces.sh' "$CONFIG_LOG" \
  || fail "source error was not written to config log"
: >"$CONFIG_ROOT/items/spaces.sh"
printf 'ok - source errors are logged without aborting later items\n'

: >"$CALLS"
: >"$NOTICES"
run_config 0 1 || fail "helper failure aborted config loading"
grep -q '^later-item-loaded$' "$CALLS" || fail "helper failure blocked item loading"
[ "$(wc -l <"$NOTICES" | tr -d ' ')" = 1 ] || fail "helper error did not send one notice"
grep -q 'event=helper_unavailable rc=17' "$CONFIG_LOG" \
  || fail "helper error was not written to config log"
printf 'ok - helper failure degrades and sends one notice\n'

: >"$CALLS"
: >"$NOTICES"
run_config 0 0 || fail "clean config load failed"
[ ! -s "$NOTICES" ] || fail "clean config load sent a notice"
[ ! -s "$CONFIG_LOG" ] || fail "clean config load left stale errors"
printf 'ok - clean load resets the log and sends no notice\n'

unsafe_home="$TEST_ROOT/unsafe-home"
mkdir -p "$unsafe_home/Library/Logs" "$TEST_ROOT/log-target"
ln -s "$TEST_ROOT/log-target" "$unsafe_home/Library/Logs/sketchybar"
: >"$NOTICES"
PATH="$FAKE_BIN:$PATH" HOME="$unsafe_home" BAR_NAME=sketchybar \
  CONFIG_DIR="$CONFIG_ROOT" CONFIG_TEST_CALLS="$CALLS" \
  CONFIG_TEST_NOTICES="$NOTICES" /bin/bash "$CONFIG_ROOT/sketchybarrc" \
  || fail "unsafe log path aborted config loading"
grep -q '/opt/homebrew/var/log/sketchybar/sketchybar.err.log' "$NOTICES" \
  || fail "unavailable config log did not fall back to service stderr"
printf 'ok - unavailable config log falls back to service stderr\n'

printf '1..5\n'
