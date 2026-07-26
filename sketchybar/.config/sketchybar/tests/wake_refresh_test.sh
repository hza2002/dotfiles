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

CALLS="$CALLS" SENDER=manual SKETCHYBAR_BIN="$FAKE_BIN" \
  "$CONFIG_ROOT/plugins/wake_refresh.sh" 2>"$STDERR_LOG"
[ ! -e "$CALLS" ]

CALLS="$CALLS" SENDER=system_woke SKETCHYBAR_BIN="$FAKE_BIN" \
SKETCHYBAR_WAKE_LOCK="$TEST_ROOT/wake.lock" \
  "$CONFIG_ROOT/plugins/wake_refresh.sh" 2>"$STDERR_LOG"

[ "$(sed -n '1p' "$CALLS")" = "--bar display=main" ]
[ "$(sed -n '2p' "$CALLS")" = "--bar display=all" ]
[ "$(wc -l < "$CALLS" | tr -d ' ')" = 2 ]
grep -q 'component=wake_refresh' "$STDERR_LOG"
grep -q 'phase=completed' "$STDERR_LOG"

printf 'ok - sender guard, display sequencing, and inherited stderr\n'
printf '1..1\n'
