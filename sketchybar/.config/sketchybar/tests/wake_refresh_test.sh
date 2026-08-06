#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-wake-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
chmod 700 "$TEST_ROOT"

FAKE_BIN="$TEST_ROOT/sketchybar"
CALLS="$TEST_ROOT/calls"
STDERR_LOG="$TEST_ROOT/stderr"

printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "$CALLS"\n' > "$FAKE_BIN"
chmod 700 "$FAKE_BIN"

CALLS="$CALLS" HOME="$TEST_ROOT" SENDER=manual SKETCHYBAR_BIN="$FAKE_BIN" \
  "$CONFIG_ROOT/plugins/wake_refresh.sh" 2>"$STDERR_LOG"
[ ! -e "$CALLS" ]

CALLS="$CALLS" HOME="$TEST_ROOT" SENDER=system_woke SKETCHYBAR_BIN="$FAKE_BIN" \
  "$CONFIG_ROOT/plugins/wake_refresh.sh" 2>"$STDERR_LOG"

[ "$(sed -n '1p' "$CALLS")" = "--bar display=main" ]
[ "$(sed -n '2p' "$CALLS")" = "--bar display=all" ]
[ "$(wc -l < "$CALLS" | tr -d ' ')" = 2 ]
grep -q 'component=wake_refresh' "$STDERR_LOG"
grep -q 'phase=completed' "$STDERR_LOG"

UNSAFE_HOME="$TEST_ROOT/unsafe-home"
mkdir -p "$UNSAFE_HOME/Library/Caches" "$TEST_ROOT/cache-target"
ln -s "$TEST_ROOT/cache-target" "$UNSAFE_HOME/Library/Caches/sketchybar"
if CALLS="$CALLS" HOME="$UNSAFE_HOME" SENDER=system_woke SKETCHYBAR_BIN="$FAKE_BIN" \
  "$CONFIG_ROOT/plugins/wake_refresh.sh" 2>>"$STDERR_LOG"; then
  printf 'wake_refresh_test: symlink cache directory accepted\n' >&2
  exit 1
fi
[ "$(wc -l < "$CALLS" | tr -d ' ')" = 2 ]

printf 'ok - sender guard, display sequencing, and inherited stderr\n'
printf '1..1\n'
