#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HELPER_DIR="$CONFIG_ROOT/helper"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-helper-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
chmod 700 "$TEST_ROOT"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$1"
}

export SKETCHYBAR_HELPER_RUNTIME_DIR="$TEST_ROOT/runtime"
# shellcheck source=../helper/runtime.sh
source "$HELPER_DIR/runtime.sh"

helper_runtime_init || fail "secure runtime directory"
[ "$(stat -f '%Lp' "$HELPER_RUNTIME_DIR")" = 700 ] || fail "runtime mode"
pass "secure runtime directory"

helper_state_read || fail "empty recovery state"
[ "$HELPER_RECOVERY_STATUS:$HELPER_RECOVERY_FAILURES" = closed:0 ] \
  || fail "empty recovery values"
helper_state_write closed 1 || fail "write first failure"
helper_state_read || fail "read first failure"
[ "$HELPER_RECOVERY_STATUS:$HELPER_RECOVERY_FAILURES" = closed:1 ] \
  || fail "first failure values"
helper_state_write open 2 || fail "write open circuit"
helper_state_read && fail "open circuit return"
[ "$HELPER_RECOVERY_STATUS:$HELPER_RECOVERY_FAILURES" = open:2 ] \
  || fail "open circuit values"
pass "bounded recovery state"

printf 'invalid state\n' > "$HELPER_RUNTIME_DIR/recovery.state"
chmod 600 "$HELPER_RUNTIME_DIR/recovery.state"
helper_state_read && fail "corrupt state accepted"
[ "$HELPER_RECOVERY_STATUS" = open ] || fail "corrupt state did not fail closed"
pass "corrupt state fails closed"

marker="$HELPER_RUNTIME_DIR/install-in-progress"
identity="$(helper_process_identity "$$")"
nonce=0123456789abcdef
printf '%s %s %s %s\n' "$$" "$identity" "$nonce" "$(( $(date +%s) + 10 ))" > "$marker"
chmod 600 "$marker"
helper_marker_valid || fail "live marker rejected"
printf '%s %s %s %s\n' "$$" "$identity" "$nonce" "$(( $(date +%s) - 1 ))" > "$marker"
helper_marker_valid && fail "expired marker accepted"
pass "installer marker validation"

rm -f "$marker" "$HELPER_RUNTIME_DIR/recovery.state"
fake_bin="$TEST_ROOT/bin"
fake_helper_dir="$TEST_ROOT/helper"
recovery_calls="$TEST_ROOT/recovery.calls"
recovery_log="$TEST_ROOT/recovery.log"
mkdir -m 700 "$fake_bin" "$fake_helper_dir"
cp "$HELPER_DIR/runtime.sh" "$HELPER_DIR/helper-run.sh" "$fake_helper_dir/"
printf '#!/bin/bash\nexit 137\n' > "$fake_helper_dir/helper"
printf '#!/bin/bash\nif [ "$1" = print ]; then\n  printf "\\tpid = 123\\n\\truns = 1\\n"\n  exit 0\nfi\nprintf "%%s\\n" "$*" >> "$RECOVERY_CALLS"\n' > "$fake_bin/launchctl"
chmod 700 "$fake_bin/launchctl" "$fake_helper_dir/helper" "$fake_helper_dir/helper-run.sh"
PATH="$fake_bin:$PATH" RECOVERY_CALLS="$recovery_calls" \
  "$fake_helper_dir/helper-run.sh" git.felix.helper 2>> "$recovery_log"
helper_state_read || fail "first recovery state"
[ "$HELPER_RECOVERY_STATUS:$HELPER_RECOVERY_FAILURES" = closed:1 ] \
  || fail "first recovery values"
PATH="$fake_bin:$PATH" RECOVERY_CALLS="$recovery_calls" \
  "$fake_helper_dir/helper-run.sh" git.felix.helper 2>> "$recovery_log"
[ "$(wc -l < "$recovery_calls" | tr -d ' ')" = 2 ] \
  || fail "recovery restart bound"
helper_state_read && fail "recovery circuit stayed closed"
[ "$HELPER_RECOVERY_STATUS:$HELPER_RECOVERY_FAILURES" = open:2 ] \
  || fail "recovery circuit values"
pass "two-restart recovery bound"

printf 'invalid state\n' > "$HELPER_RUNTIME_DIR/recovery.state"
chmod 600 "$HELPER_RUNTIME_DIR/recovery.state"
PATH="$fake_bin:$PATH" RECOVERY_CALLS="$recovery_calls" \
  "$fake_helper_dir/helper-run.sh" git.felix.helper 2>> "$recovery_log"
[ "$(wc -l < "$recovery_calls" | tr -d ' ')" = 3 ] \
  || fail "corrupt-state degraded restart"
grep -q 'reason=degraded-transition' "$recovery_log" \
  || fail "degraded restart diagnostic"
pass "corrupt state transitions to degraded bar"

build_dir="$TEST_ROOT/build"
mkdir -m 700 "$build_dir"
make -C "$HELPER_DIR" OUTPUT="$build_dir/helper" >/dev/null \
  || fail "isolated helper build"
[ -x "$build_dir/helper" ] || fail "isolated binary missing"
if make -C "$HELPER_DIR" >/dev/null 2>&1; then
  fail "direct make overwrote installed target"
fi
pass "explicit build output"

fake_config="$TEST_ROOT/config"
mkdir -m 700 "$fake_config" "$fake_config/helper"
cp "$HELPER_DIR/install.sh" "$HELPER_DIR/runtime.sh" "$fake_config/helper/"
printf '#!/bin/bash\n' > "$fake_config/sketchybarrc"
printf 'int main(void) { return 0; }\n' > "$fake_config/helper/helper.c"
printf 'installed sentinel\n' > "$fake_config/helper/helper"
chmod 700 "$fake_config/helper/helper" "$fake_config/helper/install.sh"
installed_hash="$(shasum -a 256 "$fake_config/helper/helper" | awk '{print $1}')"
if SKETCHYBAR_HELPER_RUNTIME_DIR="$HELPER_RUNTIME_DIR" \
  "$fake_config/helper/install.sh" --rollback x y z no no >/dev/null 2>&1; then
  fail "internal installer mode accepted"
fi
[ "$(shasum -a 256 "$fake_config/helper/helper" | awk '{print $1}')" = "$installed_hash" ] \
  || fail "rejected installer arguments changed target"
pass "installer exposes only the install command"

absence_bin="$TEST_ROOT/absence-bin"
mkdir -m 700 "$absence_bin"
printf '%s\n' \
  '#!/bin/bash' \
  'if [ "${PS_MODE:-none}" = failure ]; then' \
  '  exit 1' \
  'fi' \
  'if [ "${PS_MODE:-none}" = orphan ]; then' \
  '  printf "777 1 %s git.felix.helper\n" "$ABSENCE_HELPER"' \
  'fi' \
  > "$absence_bin/ps"
chmod 700 "$absence_bin/ps"
ABSENCE_HELPER="$fake_config/helper/helper"
PATH="$absence_bin:$PATH" PS_MODE=none ABSENCE_HELPER="$ABSENCE_HELPER" \
  helper_process_absent "$ABSENCE_HELPER" "$fake_config/helper/helper-run.sh" git.felix.helper \
  || fail "empty degraded process set rejected"
if PATH="$absence_bin:$PATH" PS_MODE=orphan ABSENCE_HELPER="$ABSENCE_HELPER" \
  helper_process_absent "$ABSENCE_HELPER" "$fake_config/helper/helper-run.sh" git.felix.helper; then
  fail "orphan helper accepted as absent"
fi
if PATH="$absence_bin:$PATH" PS_MODE=failure ABSENCE_HELPER="$ABSENCE_HELPER" \
  helper_process_absent "$ABSENCE_HELPER" "$fake_config/helper/helper-run.sh" git.felix.helper; then
  fail "failed process inspection accepted as absent"
fi
pass "degraded verification rejects orphan and inspection failure"

if grep -Eq 'make|clang|helper-build[.]sha' \
  "$CONFIG_ROOT/sketchybarrc" "$HELPER_DIR/start.sh"; then
  fail "normal config path can build helper"
fi
if grep -Eq -- '--activate|--rollback|--finish|--recover' \
  "$HELPER_DIR/install.sh" "$HELPER_DIR/helper-run.sh"; then
  fail "internal transaction mode exposed"
fi
grep -q 'lockf -s -t 10 8' "$HELPER_DIR/install.sh" \
  || fail "installer lock is not caller-owned"
grep -q 'STARTUP_LOCK_TIMEOUT=$((READY_TIMEOUT + 15))' "$HELPER_DIR/start.sh" \
  || fail "startup lock does not cover bounded startup work"
grep -q 'rollback_transaction' "$HELPER_DIR/install.sh" \
  || fail "phase-aware rollback missing"
pass "source invariants prevent config-time build and unsafe lock modes"

printf '1..10\n'
