#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PLUGIN="$CONFIG_ROOT/plugins/caffeinate.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-caffeinate-test.XXXXXX")"
STATE_DIR="$TEST_ROOT/state"
FAKE_BIN="$TEST_ROOT/bin"
PROC_DIR="$TEST_ROOT/processes"
LOG_DIR="$TEST_ROOT/logs"
NOW_FILE="$TEST_ROOT/now"
OBS_MODE="$TEST_ROOT/observe-mode"
DIAG_LOG="$STATE_DIR/caffeinate.log"
TEST_COUNT=0
REAL_PID=""

cleanup() {
  local f pid command
  [ -z "$REAL_PID" ] || kill -TERM "$REAL_PID" 2>/dev/null || true
  for f in "$PROC_DIR"/*; do
    [ -f "$f" ] || continue
    pid=${f##*/}
    command=$(/bin/ps -ww -p "$pid" -o command= 2>/dev/null || true)
    case "$command" in *"$FAKE_BIN/caffeinate"*) kill -TERM "$pid" 2>/dev/null || true ;; esac
  done
  sleep 0.1
  if [ "${CAFFEINATE_TEST_KEEP:-0}" = 1 ]; then
    printf 'kept test root: %s\n' "$TEST_ROOT" >&2
    return
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { TEST_COUNT=$((TEST_COUNT + 1)); printf 'ok - %s\n' "$1"; }
assert_eq() { [ "$1" = "$2" ] || fail "$3 (wanted '$2', got '$1')"; }
assert_le() { [ "$1" -le "$2" ] || fail "$3 (maximum '$2', got '$1')"; }
now_ms() { /usr/bin/perl -MTime::HiRes=time -e 'printf "%.0f\n", time() * 1000'; }
state_value() { sed -n "s/^$1=//p" "$STATE_DIR/caffeinate.state"; }
pending_value() { sed -n "s/^$1=//p" "$STATE_DIR/caffeinate.pending"; }
process_count() { find "$PROC_DIR" -type f 2>/dev/null | wc -l | tr -d ' '; }

mkdir -p "$STATE_DIR" "$FAKE_BIN" "$PROC_DIR" "$LOG_DIR"
printf '1000000\n' >"$NOW_FILE"

cat >"$FAKE_BIN/caffeinate" <<'SH'
#!/bin/bash
proc_dir=${CAFFEINATE_FAKE_PROC_DIR:?}
printf '%s\n' "$*" >"$proc_dir/$$"
cleanup() {
  rm -f "$proc_dir/$$"
  exit 0
}
trap cleanup TERM INT EXIT
[ ! -f "${CAFFEINATE_FAKE_LOG_DIR:?}/caffeinate-fail" ] || exit 1
while :; do /bin/sleep 0.05; done
SH

cat >"$FAKE_BIN/observe" <<'SH'
#!/bin/bash
pid=$1
proc_dir=${CAFFEINATE_FAKE_PROC_DIR:?}
mode_file=${CAFFEINATE_FAKE_OBS_MODE:?}
printf '%s\n' "$pid" >>"${CAFFEINATE_FAKE_LOG_DIR:?}/observe"
mode=exact
[ ! -f "$mode_file" ] || mode=$(cat "$mode_file")
case "$mode" in
indeterminate) printf 'indeterminate||\n'; exit 0 ;;
esac
if [ -f "$proc_dir/$pid" ]; then
  args=$(cat "$proc_dir/$pid")
  [ "$mode" != mismatch ] || { printf 'mismatch|replacement-%s|/usr/bin/other\n' "$pid"; exit 0; }
  printf 'exact|start-%s|/usr/bin/caffeinate %s\n' "$pid" "$args"
elif kill -0 "$pid" 2>/dev/null; then
  printf 'mismatch|start-%s|/usr/bin/other\n' "$pid"
else
  printf 'absent||\n'
fi
SH

cat >"$FAKE_BIN/sketchybar" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"${CAFFEINATE_FAKE_LOG_DIR:?}/sketchybar"
SH

cat >"$FAKE_BIN/pmset" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"${CAFFEINATE_FAKE_LOG_DIR:?}/pmset"
[ ! -f "${CAFFEINATE_FAKE_LOG_DIR:?}/pmset-fail" ]
SH

cat >"$FAKE_BIN/osascript" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"${CAFFEINATE_FAKE_LOG_DIR:?}/osascript"
[ -z "${CAFFEINATE_FAKE_OSASCRIPT_OUTPUT:-}" ] \
  || printf '%s\n' "$CAFFEINATE_FAKE_OSASCRIPT_OUTPUT"
SH

cat >"$FAKE_BIN/now" <<'SH'
#!/bin/bash
cat "${CAFFEINATE_FAKE_NOW:?}"
SH
chmod +x "$FAKE_BIN"/*

export CAFFEINATE_FAKE_PROC_DIR="$PROC_DIR"
export CAFFEINATE_FAKE_OBS_MODE="$OBS_MODE"
export CAFFEINATE_FAKE_LOG_DIR="$LOG_DIR"
export CAFFEINATE_FAKE_NOW="$NOW_FILE"

plugin() {
  local -a runner
  if [ "${CAFFEINATE_TEST_TRACE:-0}" = 1 ]; then runner=(/bin/bash -x "$PLUGIN"); else runner=("$PLUGIN"); fi
  CONFIG_DIR="$CONFIG_ROOT" \
  CAFFEINATE_TEST_ROOT="$TEST_ROOT" \
  CAFFEINATE_TEST_CAFFEINATE="$FAKE_BIN/caffeinate" \
  CAFFEINATE_TEST_SKETCHYBAR="$FAKE_BIN/sketchybar" \
  CAFFEINATE_TEST_PMSET="$FAKE_BIN/pmset" \
  CAFFEINATE_TEST_OSASCRIPT="$FAKE_BIN/osascript" \
  CAFFEINATE_TEST_OBSERVER="$FAKE_BIN/observe" \
  CAFFEINATE_TEST_NOW="$FAKE_BIN/now" \
  CAFFEINATE_TEST_KILLPOINT="${CAFFEINATE_TEST_KILLPOINT:-}" \
  CAFFEINATE_TEST_CANDIDATE_DELAY="${CAFFEINATE_TEST_CANDIDATE_DELAY:-}" \
  "${runner[@]}" __test__ "$@"
}

real_plugin() {
  local root=$1
  shift
  CONFIG_DIR="$CONFIG_ROOT" CAFFEINATE_TEST_ROOT="$root" \
  CAFFEINATE_TEST_CAFFEINATE=/usr/bin/caffeinate \
  CAFFEINATE_TEST_SKETCHYBAR="$FAKE_BIN/sketchybar" \
  CAFFEINATE_TEST_PMSET="$FAKE_BIN/pmset" \
  CAFFEINATE_TEST_OSASCRIPT="$FAKE_BIN/osascript" \
  CAFFEINATE_TEST_OBSERVER= CAFFEINATE_TEST_NOW="$FAKE_BIN/now" \
  "$PLUGIN" __test__ "$@"
}

wait_for() {
  local tries=0
  while ! eval "$1"; do
    tries=$((tries + 1))
    [ "$tries" -lt 80 ] || fail "$2"
    sleep 0.05
  done
}

plugin render
grep -q 'apple.logo icon.color=0xfffbf1c7' "$LOG_DIR/sketchybar" \
  || fail 'idle render did not set Apple white'
grep -q 'update_freq=30' "$LOG_DIR/sketchybar" \
  || fail 'idle render disabled the crash-recovery heartbeat'
pass 'idle UI is white and retains the crash-recovery heartbeat'

rm -f "$STATE_DIR/caffeinate.log.lock"
mkdir "$STATE_DIR/caffeinate.log.lock"
plugin render
rmdir "$STATE_DIR/caffeinate.log.lock"
ln -s "$TEST_ROOT/missing-log-lock-target" "$STATE_DIR/caffeinate.log.lock"
plugin display-toggle
assert_eq "$(state_value DISPLAY)" 1 'unsafe diagnostic lock blocked a mutation'
plugin stop
[ ! -e "$TEST_ROOT/missing-log-lock-target" ] || fail 'diagnostic lock followed a symlink'
rm -f "$STATE_DIR/caffeinate.log.lock"
assert_eq "$(process_count)" 0 'disabled diagnostics leaked an owner'
pass 'diagnostic failures never block state handling'

cat >"$STATE_DIR/caffeinate.pending" <<EOF
PHASE=PREPARED
TXID=heartbeat
OLD_PID=
OLD_START=
OLD_MODE=off
OLD_END=
OLD_TIMEOUT=
OLD_DISPLAY=0
OLD_ARGV=
TARGET_MODE=forever
TARGET_END=
TARGET_DISPLAY=1
CAND_TOKEN=
CAND_PID=
CAND_START=
CAND_ARGV=
CAND_TIMEOUT=
RETRY_AT=1000030
RETRY_COUNT=1
EOF
: >"$LOG_DIR/sketchybar"
plugin render
grep -q 'update_freq=30' "$LOG_DIR/sketchybar" \
  || fail 'pending recovery without a main owner disabled its heartbeat'
rm -f "$STATE_DIR/caffeinate.pending"
pass 'pending recovery remains autonomously scheduled without a main owner'

: >"$LOG_DIR/observe"
plugin display-toggle
assert_eq "$(state_value MODE)" forever 'Apple from 00 did not select forever'
assert_eq "$(state_value DISPLAY)" 1 'Apple from 00 did not enter 11'
assert_eq "$(state_value ARGV)" '/usr/bin/caffeinate -di' '11 argv is not canonical'
assert_eq "$(process_count)" 1 '11 did not have one owner process'
grep -q 'apple.logo icon.color=0xfffe8019' "$LOG_DIR/sketchybar" \
  || fail '11 did not render Apple orange'
startup_observations=$(wc -l <"$LOG_DIR/observe" | tr -d ' ')
assert_le "$startup_observations" 4 \
  'Apple 00 -> 11 repeated process observation'
first_pid=$(state_value PID)
pass "Apple 00 -> 11 ($startup_observations process observations)"
grep -q 'event=mutation_begin action=display-toggle' "$DIAG_LOG" \
  || fail 'diagnostic log omitted the initiating action'
grep -q 'event=transaction_prepared .*target=forever display=1' "$DIAG_LOG" \
  || fail 'diagnostic log omitted the durable target'
grep -q 'event=state_commit .*mode=forever display=1' "$DIAG_LOG" \
  || fail 'diagnostic log omitted the committed state'
grep -q 'event=mutation_end action=display-toggle rc=0 pending=none phase=none state=valid mode=forever display=1' \
  "$DIAG_LOG" || fail 'diagnostic log retained stale transaction fields'
assert_eq "$(stat -f %Lp "$DIAG_LOG")" 600 'diagnostic log permissions are not private'
pass 'diagnostic log records actions, targets, and commits privately'

: >"$LOG_DIR/observe"
mock_transition_started=$(now_ms)
plugin display-toggle
mock_transition_elapsed=$(($(now_ms) - mock_transition_started))
assert_eq "$(state_value DISPLAY)" 0 'Apple 11 did not enter 10'
assert_eq "$(state_value ARGV)" '/usr/bin/caffeinate -i' '10 argv is not canonical'
[ "$(state_value PID)" != "$first_pid" ] || fail 'flag replacement reused the old process'
assert_eq "$(process_count)" 1 'flag replacement left multiple processes'
replacement_observations=$(wc -l <"$LOG_DIR/observe" | tr -d ' ')
assert_le "$replacement_observations" 10 \
  'Apple 11 -> 10 repeated process observation'
assert_le "$mock_transition_elapsed" 1500 'mocked controller transition exceeded 1500ms'
pass "Apple 11 -> 10 replaces one owner ($replacement_observations process observations)"

plugin display-toggle
assert_eq "$(state_value DISPLAY)" 1 'Apple 10 did not return to 11'
plugin display-toggle &
concurrent_first=$!
plugin display-toggle &
concurrent_second=$!
wait "$concurrent_first" || fail 'first concurrent display toggle failed'
wait "$concurrent_second" || fail 'second concurrent display toggle failed'
assert_eq "$(state_value DISPLAY)" 1 'concurrent display toggles lost serialization'
assert_eq "$(process_count)" 1 'concurrent display toggles changed owner count'
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'concurrent display toggles retained pending'
pass 'concurrent display toggles serialize through one owner'

plugin toggle
[ ! -e "$STATE_DIR/caffeinate.state" ] || fail 'C active -> 00 retained state'
wait_for '[ "$(process_count)" = 0 ]' 'C active -> 00 retained a process'
pass 'C active -> 00'

plugin toggle
assert_eq "$(state_value DISPLAY)" 0 'C 00 -> 10 enabled display'
assert_eq "$(state_value ARGV)" '/usr/bin/caffeinate -i' 'C 00 -> 10 argv mismatch'
plugin display-toggle
plugin hours 1
assert_eq "$(state_value DISPLAY)" 1 'new duration did not preserve DISPLAY'
assert_eq "$(state_value END)" 1003600 'finite END mismatch'
assert_eq "$(state_value TIMEOUT)" 3600 'finite TIMEOUT was not rebased'
assert_eq "$(state_value ARGV)" '/usr/bin/caffeinate -di -t 3600' 'finite 11 argv mismatch'
pass 'duration preserves DISPLAY and canonical timeout'

expiring_pid=$(state_value PID)
printf '1003600\n' >"$NOW_FILE"
plugin render
wait_for '[ ! -e "$STATE_DIR/caffeinate.state" ]' 'expired exact state was not cleaned'
wait_for '[ ! -e "$PROC_DIR/'"$expiring_pid"'" ]' 'expired exact owner was orphaned'
printf '1000000\n' >"$NOW_FILE"
plugin display-toggle
plugin hours 1
pass 'deadline expiry stops an exact live owner before clearing state'

plugin display-sleep
assert_eq "$(state_value DISPLAY)" 0 'display-sleep did not enter 10'
grep -qx 'displaysleepnow' "$LOG_DIR/pmset" || fail 'display-sleep did not call pmset'
assert_eq "$(process_count)" 1 'display-sleep changed owner count'
pass 'display-sleep serializes 11 -> 10 -> pmset'

plugin display-toggle
touch "$LOG_DIR/pmset-fail"
set +e
plugin display-sleep
rc=$?
set -e
rm -f "$LOG_DIR/pmset-fail"
[ "$rc" -ne 0 ] || fail 'pmset failure was reported as success'
assert_eq "$(state_value DISPLAY)" 0 'pmset failure restored DISPLAY=1'
grep -q 'event=error category=pmset' "$DIAG_LOG" \
  || fail 'diagnostic log omitted the pmset failure category'
pass 'pmset failure keeps authoritative state 10'

before=$(shasum -a 256 "$STATE_DIR/caffeinate.state")
export BUTTON=middle
plugin click
unset BUTTON
after=$(shasum -a 256 "$STATE_DIR/caffeinate.state")
assert_eq "$after" "$before" 'unknown BUTTON mutated state'
pass 'unknown button is a no-op'

set +e
plugin hours '1+1'
rc=$?
set -e
assert_eq "$rc" 64 'arithmetic duration input was accepted'
pass 'duration input is strictly validated'

export CAFFEINATE_FAKE_OSASCRIPT_OUTPUT=09h30m
plugin custom
unset CAFFEINATE_FAKE_OSASCRIPT_OUTPUT
assert_eq "$(state_value END)" 1034200 'leading-zero custom duration parsed incorrectly'
assert_eq "$(state_value TIMEOUT)" 34200 'leading-zero custom timeout parsed incorrectly'
pass 'custom duration uses decimal arithmetic'

plugin stop
printf 'PID=%s\nSTART=old-start\nMODE=forever\nEND=\nTIMEOUT=\nDISPLAY=0\nARGV=/usr/bin/caffeinate -i\n' \
  "$$" >"$STATE_DIR/caffeinate.state"
plugin stop
kill -0 $$ || fail 'PID mismatch killed the replacement process'
[ ! -e "$STATE_DIR/caffeinate.state" ] || fail 'PID mismatch state was retained'
pass 'PID reuse is never killed'

plugin forever
indeterminate_state=$(shasum -a 256 "$STATE_DIR/caffeinate.state")
printf 'indeterminate\n' >"$OBS_MODE"
set +e
plugin display-toggle
rc=$?
set -e
[ "$rc" -ne 0 ] || fail 'indeterminate observation allowed mutation'
assert_eq "$(shasum -a 256 "$STATE_DIR/caffeinate.state")" "$indeterminate_state" \
  'indeterminate observation changed state'
rm -f "$OBS_MODE"
pass 'indeterminate observation fails closed'

invalid_pid=$(state_value PID)
printf 'broken\n' >"$STATE_DIR/caffeinate.state"
: >"$LOG_DIR/sketchybar"
plugin render
grep -q 'caffeinate label=狀態異常' "$LOG_DIR/sketchybar" \
  || fail 'invalid state did not render a warning'
grep -q 'apple.logo icon.color=0xfffb4934' "$LOG_DIR/sketchybar" \
  || fail 'invalid state did not mark Apple as indeterminate'
kill -TERM "$invalid_pid" 2>/dev/null || true
wait_for '[ ! -e "$PROC_DIR/'"$invalid_pid"'" ]' 'invalid-state fixture process did not exit'
rm -f "$STATE_DIR/caffeinate.state"
pass 'invalid main state renders an explicit warning'

plugin forever
dead_pid=$(state_value PID)
kill -TERM "$dead_pid"
wait_for '[ ! -e "$PROC_DIR/'"$dead_pid"'" ]' 'fake caffeinate did not exit'
plugin render
wait_for '[ ! -e "$STATE_DIR/caffeinate.state" ]' 'render recovery did not clean early exit'
pass 'periodic render recovers an early exit'

export CAFFEINATE_TEST_KILLPOINT=PREPARED
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
assert_eq "$rc" 99 'PREPARED killpoint did not interrupt'
assert_eq "$(pending_value PHASE)" PREPARED 'PREPARED journal was not durable'
plugin __recover__
assert_eq "$(state_value DISPLAY)" 1 'PREPARED recovery did not complete target'
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'PREPARED recovery retained pending'
grep -q 'event=recovery_begin .*phase=PREPARED' "$DIAG_LOG" \
  || fail 'diagnostic log omitted crash recovery provenance'
pass 'PREPARED crash resumes deterministically'

export CAFFEINATE_TEST_KILLPOINT=PREPARED
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
assert_eq "$rc" 99 'second PREPARED killpoint did not interrupt'
plugin stop
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'new mutation retained recovered pending'
[ ! -e "$STATE_DIR/caffeinate.state" ] || fail 'new mutation was dropped after pending recovery'
assert_eq "$(process_count)" 0 'new mutation after pending recovery retained a process'
pass 'new mutation continues after pending recovery'

plugin forever
export CAFFEINATE_TEST_KILLPOINT=OLD_STOPPING
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
assert_eq "$rc" 99 'OLD_STOPPING killpoint did not interrupt'
assert_eq "$(process_count)" 2 'make-before-break did not keep both verified owners'
plugin __recover__
assert_eq "$(state_value DISPLAY)" 1 'OLD_STOPPING recovery lost the target'
assert_eq "$(process_count)" 1 'OLD_STOPPING recovery did not converge to one owner'
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'OLD_STOPPING recovery retained pending'
pass 'make-before-break recovers without an assertion gap'

plugin stop
export CAFFEINATE_TEST_KILLPOINT=TARGET_STARTING
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
assert_eq "$rc" 99 'TARGET_STARTING killpoint did not interrupt'
pre_spawn_token=$(pending_value CAND_TOKEN)
plugin __recover__
assert_eq "$(state_value DISPLAY)" 1 'pre-spawn recovery lost the durable target'
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'pre-spawn recovery retained pending'
assert_eq "$(process_count)" 1 'pre-spawn recovery did not converge to one owner'
wait_for '[ ! -e "$STATE_DIR/caffeinate.candidate.'"$pre_spawn_token"'.control" ]' \
  'pre-spawn recovery retained its cancelled control'
plugin stop
pass 'pre-spawn crash restarts the durable target'

export CAFFEINATE_TEST_KILLPOINT=TARGET_FORKED
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
assert_eq "$rc" 99 'TARGET_FORKED killpoint did not interrupt'
forked_token=$(pending_value CAND_TOKEN)
/bin/sleep 2.2
plugin __recover__
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'unpublished fork recovery retained pending'
assert_eq "$(state_value DISPLAY)" 1 'unpublished fork recovery lost the durable target'
assert_eq "$(process_count)" 1 'unpublished fork recovery did not converge to one owner'
wait_for '[ ! -e "$STATE_DIR/caffeinate.candidate.'"$forked_token"'.control" ]' \
  'unpublished fork did not acknowledge cancellation'
plugin stop
pass 'unpublished fork is cancelled without losing the durable target'

plugin forever
export CAFFEINATE_TEST_CANDIDATE_DELAY=0.3
export CAFFEINATE_TEST_KILLPOINT=TARGET_FORKED
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
forked_token=$(pending_value CAND_TOKEN)
plugin __recover__
unset CAFFEINATE_TEST_CANDIDATE_DELAY
assert_eq "$rc" 99 'active TARGET_FORKED killpoint did not interrupt'
assert_eq "$(state_value DISPLAY)" 1 'unpublished replacement lost the durable target'
assert_eq "$(process_count)" 1 'unpublished replacement did not converge to one owner'
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'active fork recovery retained pending'
wait_for '[ ! -e "$STATE_DIR/caffeinate.candidate.'"$forked_token"'.control" ]' \
  'delayed unpublished fork did not acknowledge cancellation'
pass 'unpublished replacement cancels its waiter and completes the target'

plugin stop

export CAFFEINATE_TEST_KILLPOINT=TARGET_CLAIMED
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
assert_eq "$rc" 99 'TARGET_CLAIMED killpoint did not interrupt'
/bin/sleep 2.2
plugin __recover__
assert_eq "$(state_value DISPLAY)" 1 'claimed candidate recovery lost target'
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'claimed candidate recovery retained pending'
assert_eq "$(process_count)" 1 'claimed candidate recovery lost or duplicated process'
pass 'an expired published waiter restarts from the durable target'

plugin display-toggle
active_pid=$(state_value PID)
active_state=$(shasum -a 256 "$STATE_DIR/caffeinate.state")
touch "$LOG_DIR/caffeinate-fail"
set +e
plugin display-toggle
rc=$?
set -e
rm -f "$LOG_DIR/caffeinate-fail"
[ "$rc" -ne 0 ] || fail 'active candidate launch failure returned success'
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'active launch failure retained pending'
assert_eq "$(state_value PID)" "$active_pid" 'active launch failure replaced the old owner'
assert_eq "$(shasum -a 256 "$STATE_DIR/caffeinate.state")" "$active_state" \
  'active launch failure changed the old state'
assert_eq "$(process_count)" 1 'active launch failure changed owner count'
pass 'active launch failure preserves the old owner immediately'

plugin stop
touch "$LOG_DIR/caffeinate-fail"
set +e
plugin display-toggle
rc=$?
set -e
rm -f "$LOG_DIR/caffeinate-fail"
[ "$rc" -ne 0 ] || fail 'candidate launch failure returned success'
plugin __recover__
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'launch failure recovery retained pending'
[ ! -e "$STATE_DIR/caffeinate.state" ] || fail 'launch failure recovery created state'
assert_eq "$(process_count)" 0 'launch failure recovery retained a process'
pass 'candidate launch failure is self-clearing'

: >"$LOG_DIR/sketchybar"
plugin render
grep -q 'update_freq=30' "$LOG_DIR/sketchybar" \
  || fail 'off state lacked a heartbeat before starting a transaction'
export CAFFEINATE_TEST_KILLPOINT=TARGET_CANDIDATE
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
assert_eq "$rc" 99 'TARGET_CANDIDATE killpoint did not interrupt'
grep -q 'update_freq=30' "$LOG_DIR/sketchybar" \
  || fail 'controller crash lost its pre-existing recovery heartbeat'
printf 'indeterminate\n' >"$OBS_MODE"
plugin __recover__
assert_eq "$(pending_value RETRY_COUNT)" 1 'first recovery did not record a retry'
assert_eq "$(pending_value RETRY_AT)" 1000030 'first recovery delay was not 30 seconds'
printf '1000030\n' >"$NOW_FILE"
plugin __recover__
assert_eq "$(pending_value RETRY_COUNT)" 2 'cleanup retry count was reset'
assert_eq "$(pending_value RETRY_AT)" 1000090 'second recovery delay was not 60 seconds'
rm -f "$OBS_MODE"
printf '1000090\n' >"$NOW_FILE"
plugin __recover__
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'backoff recovery retained pending'
assert_eq "$(process_count)" 1 'backoff recovery lost the candidate'
printf '1000000\n' >"$NOW_FILE"
plugin stop
pass 'cleanup recovery uses increasing backoff'

export CAFFEINATE_TEST_KILLPOINT=COMMITTED
set +e
plugin display-toggle
rc=$?
set -e
unset CAFFEINATE_TEST_KILLPOINT
assert_eq "$rc" 99 'COMMITTED killpoint did not interrupt'
[ -e "$STATE_DIR/caffeinate.state" ] && [ -e "$STATE_DIR/caffeinate.pending" ] \
  || fail 'commit crash fixtures were not present'
plugin __recover__
[ ! -e "$STATE_DIR/caffeinate.pending" ] || fail 'commit recovery retained pending'
assert_eq "$(process_count)" 1 'commit recovery duplicated the process'
pass 'commit-before-cleanup crash is idempotent'

inode_before=$(stat -f %i "$STATE_DIR/caffeinate.recovery.lock")
CONFIG_DIR="$CONFIG_ROOT" CAFFEINATE_TEST_ROOT="$TEST_ROOT" \
  CAFFEINATE_TEST_CAFFEINATE="$FAKE_BIN/caffeinate" \
  CAFFEINATE_TEST_SKETCHYBAR="$FAKE_BIN/sketchybar" \
  CAFFEINATE_TEST_PMSET="$FAKE_BIN/pmset" \
  CAFFEINATE_TEST_OSASCRIPT="$FAKE_BIN/osascript" \
  CAFFEINATE_TEST_OBSERVER="$FAKE_BIN/observe" CAFFEINATE_TEST_NOW="$FAKE_BIN/now" \
  /usr/bin/lockf -k -t 0 "$STATE_DIR/caffeinate.recovery.lock" "$PLUGIN" __test__ __recover__
inode_after=$(stat -f %i "$STATE_DIR/caffeinate.recovery.lock")
assert_eq "$inode_after" "$inode_before" 'recovery lock inode changed'
pass 'recovery election keeps a stable lock inode'

plugin stop
mkdir -p "$TEST_ROOT/legacy"
"$FAKE_BIN/caffeinate" -i &
legacy_pid=$!
wait_for '[ -e "$PROC_DIR/'"$legacy_pid"'" ]' 'legacy owner fixture did not start'
cat >"$TEST_ROOT/legacy/caffeinate.state" <<EOF
PID=$legacy_pid
END=
MODE=forever
START=start-$legacy_pid
EOF
: >"$TEST_ROOT/legacy/caffeinate.lock"
plugin render
assert_eq "$(state_value PID)" "$legacy_pid" 'legacy owner was not adopted'
assert_eq "$(state_value DISPLAY)" 0 'legacy owner migration enabled display sleep prevention'
assert_eq "$(state_value ARGV)" '/usr/bin/caffeinate -i' 'legacy owner migration changed argv'
[ ! -e "$TEST_ROOT/legacy/caffeinate.state" ] || fail 'legacy state remained after adoption'
plugin stop
wait_for '[ ! -e "$PROC_DIR/'"$legacy_pid"'" ]' 'adopted legacy owner was not stoppable'
pass 'live legacy owner is adopted without duplication'

"$FAKE_BIN/caffeinate" -i &
legacy_pid=$!
wait_for '[ -e "$PROC_DIR/'"$legacy_pid"'" ]' 'locked legacy owner fixture did not start'
rm -f "$TEST_ROOT/legacy/caffeinate.state"
(
  exec 6>>"$TEST_ROOT/legacy/caffeinate.lock"
  /usr/bin/lockf -s 6
  : >"$TEST_ROOT/legacy-writer-ready"
  /bin/sleep 0.3
  printf 'PID=%s\nEND=\nMODE=forever\nSTART=start-%s\n' "$legacy_pid" "$legacy_pid" \
    >"$TEST_ROOT/legacy/caffeinate.state"
) &
legacy_writer=$!
wait_for '[ -e "$TEST_ROOT/legacy-writer-ready" ]' 'legacy writer did not acquire its lock'
plugin render
wait "$legacy_writer"
assert_eq "$(state_value PID)" "$legacy_pid" 'legacy state written under lock was missed'
plugin stop
pass 'legacy state is checked only after acquiring the old lock'

"$FAKE_BIN/caffeinate" -i &
legacy_pid=$!
wait_for '[ -e "$PROC_DIR/'"$legacy_pid"'" ]' 'late legacy owner fixture did not start'
cat >"$TEST_ROOT/legacy/caffeinate.state" <<EOF
PID=$legacy_pid
END=
MODE=forever
START=start-$legacy_pid
EOF
cat >"$STATE_DIR/caffeinate.pending" <<EOF
PHASE=PREPARED
TXID=late-legacy
OLD_PID=
OLD_START=
OLD_MODE=off
OLD_END=
OLD_TIMEOUT=
OLD_DISPLAY=0
OLD_ARGV=
TARGET_MODE=forever
TARGET_END=
TARGET_DISPLAY=1
CAND_TOKEN=
CAND_PID=
CAND_START=
CAND_ARGV=
CAND_TIMEOUT=
RETRY_AT=1000030
RETRY_COUNT=1
EOF
plugin render
wait_for '[ ! -e "$PROC_DIR/'"$legacy_pid"'" ]' 'late legacy owner was not stopped'
[ ! -e "$TEST_ROOT/legacy/caffeinate.state" ] || fail 'late legacy state was retained'
[ ! -e "$STATE_DIR/caffeinate.state" ] || fail 'late legacy owner was adopted over pending'
assert_eq "$(pending_value TXID)" late-legacy 'late legacy cleanup changed pending target'
rm -f "$STATE_DIR/caffeinate.pending"
pass 'late legacy owner cannot override an in-flight transaction'

plugin display-toggle
plugin hours 1
new_pid=$(state_value PID)
"$FAKE_BIN/caffeinate" -i &
legacy_pid=$!
wait_for '[ -e "$PROC_DIR/'"$legacy_pid"'" ]' 'expired fallback fixture did not start'
cat >"$TEST_ROOT/legacy/caffeinate.state" <<EOF
PID=$legacy_pid
END=
MODE=forever
START=start-$legacy_pid
EOF
printf '1003600\n' >"$NOW_FILE"
plugin render
wait_for '[ ! -e "$PROC_DIR/'"$legacy_pid"'" ]' 'expired new state revived the legacy owner'
wait_for '[ ! -e "$PROC_DIR/'"$new_pid"'" ]' 'expired new owner was not stopped'
wait_for '[ ! -e "$STATE_DIR/caffeinate.state" ]' 'expired authoritative state was retained'
printf '1000000\n' >"$NOW_FILE"
pass 'expired authoritative state never falls back to legacy forever'

plugin forever
new_pid=$(state_value PID)
kill -TERM "$new_pid"
wait_for '[ ! -e "$PROC_DIR/'"$new_pid"'" ]' 'stale new owner fixture did not exit'
"$FAKE_BIN/caffeinate" -i &
legacy_pid=$!
wait_for '[ -e "$PROC_DIR/'"$legacy_pid"'" ]' 'stale fallback fixture did not start'
cat >"$TEST_ROOT/legacy/caffeinate.state" <<EOF
PID=$legacy_pid
END=
MODE=forever
START=start-$legacy_pid
EOF
plugin render
wait_for '[ ! -e "$PROC_DIR/'"$legacy_pid"'" ]' 'stale new state revived the legacy owner'
wait_for '[ ! -e "$STATE_DIR/caffeinate.state" ]' 'stale authoritative state was retained'
pass 'stale authoritative state never falls back to legacy forever'

"$FAKE_BIN/caffeinate" -i &
legacy_pid=$!
wait_for '[ -e "$PROC_DIR/'"$legacy_pid"'" ]' 'semantic corruption fixture did not start'
cat >"$TEST_ROOT/legacy/caffeinate.state" <<EOF
PID=$legacy_pid
END=bad
MODE=garbage
START=start-$legacy_pid
EOF
plugin render
wait_for '[ ! -e "$PROC_DIR/'"$legacy_pid"'" ]' 'semantic corruption orphaned a legacy owner'
[ ! -e "$TEST_ROOT/legacy/caffeinate.state" ] || fail 'resolved semantic corruption retained legacy state'
pass 'semantic legacy corruption stops an exactly identified owner'

plugin forever
new_pid=$(state_value PID)
cat >"$TEST_ROOT/legacy/caffeinate.state" <<EOF
PID=$new_pid
END=bad
MODE=garbage
START=start-$new_pid
EOF
plugin render
assert_eq "$(state_value PID)" "$new_pid" 'corrupt legacy metadata stopped authoritative main'
kill -0 "$new_pid" 2>/dev/null || fail 'corrupt legacy metadata killed authoritative main'
[ ! -e "$TEST_ROOT/legacy/caffeinate.state" ] \
  || fail 'corrupt duplicate legacy metadata was retained'
plugin stop
pass 'authoritative main identity outranks corrupt legacy semantics'

printf 'broken\n' >"$TEST_ROOT/legacy/caffeinate.state"
: >"$LOG_DIR/sketchybar"
set +e
plugin render
rc=$?
set -e
[ "$rc" -ne 0 ] || fail 'corrupt legacy state was accepted'
[ -e "$TEST_ROOT/legacy/caffeinate.state" ] || fail 'corrupt legacy evidence was deleted'
grep -q 'caffeinate label=狀態異常' "$LOG_DIR/sketchybar" \
  || fail 'corrupt legacy state did not render a warning'
rm -f "$TEST_ROOT/legacy/caffeinate.state"
pass 'unverifiable legacy state fails closed visibly'

plugin forever
owned_pid=$(state_value PID)
assert_eq "$(process_count)" 1 'corrupt pending fixture started duplicate owners'
cat >"$STATE_DIR/caffeinate.pending" <<EOF
PHASE=PREPARED
TXID=corrupt
OLD_PID=-1
OLD_START=bad
OLD_MODE=forever
OLD_END=
OLD_TIMEOUT=
OLD_DISPLAY=0
OLD_ARGV=/usr/bin/caffeinate -i
TARGET_MODE=off
TARGET_END=
TARGET_DISPLAY=0
CAND_PID=
CAND_START=
CAND_ARGV=
CAND_TIMEOUT=
RETRY_AT=0
RETRY_COUNT=0
EOF
set +e
plugin display-toggle
rc=$?
set -e
[ "$rc" -ne 0 ] || fail 'corrupt pending PID was accepted'
kill -0 "$owned_pid" || fail 'corrupt pending signalled an owned process'
rm -f "$STATE_DIR/caffeinate.pending"
pass 'corrupt pending identity fails closed'

cat >"$STATE_DIR/caffeinate.pending" <<EOF
PHASE=PREPARED
TXID=corrupt-number
OLD_PID=
OLD_START=
OLD_MODE=off
OLD_END=
OLD_TIMEOUT=
OLD_DISPLAY=0
OLD_ARGV=
TARGET_MODE=forever
TARGET_END=
TARGET_DISPLAY=1
CAND_TOKEN=
CAND_PID=
CAND_START=
CAND_ARGV=
CAND_TIMEOUT=
RETRY_AT=1:2
RETRY_COUNT=0
EOF
: >"$LOG_DIR/sketchybar"
plugin render
grep -q 'caffeinate label=狀態異常' "$LOG_DIR/sketchybar" \
  || fail 'corrupt pending numeric field did not render a warning'
rm -f "$STATE_DIR/caffeinate.pending"
pass 'pending numeric fields reject delimiters'

cat >"$STATE_DIR/caffeinate.pending" <<EOF
PHASE=PREPARED
TXID=../escape
OLD_PID=
OLD_START=
OLD_MODE=off
OLD_END=
OLD_TIMEOUT=
OLD_DISPLAY=0
OLD_ARGV=
TARGET_MODE=forever
TARGET_END=
TARGET_DISPLAY=1
CAND_TOKEN=
CAND_PID=
CAND_START=
CAND_ARGV=
CAND_TIMEOUT=
RETRY_AT=1000030
RETRY_COUNT=0
EOF
: >"$LOG_DIR/sketchybar"
plugin render
grep -q 'caffeinate label=狀態異常' "$LOG_DIR/sketchybar" \
  || fail 'unsafe transaction ID did not render a warning'
rm -f "$STATE_DIR/caffeinate.pending"
pass 'transaction IDs reject unsafe path characters'

cat >"$STATE_DIR/caffeinate.pending" <<EOF
PHASE=TARGET_CANDIDATE
TXID=missing-candidate
OLD_PID=
OLD_START=
OLD_MODE=off
OLD_END=
OLD_TIMEOUT=
OLD_DISPLAY=0
OLD_ARGV=
TARGET_MODE=forever
TARGET_END=
TARGET_DISPLAY=1
ATTEMPT=1
CAND_TOKEN=missing-candidate.1.target
CAND_PID=
CAND_START=
CAND_ARGV=/usr/bin/caffeinate -di
CAND_TIMEOUT=
RETRY_AT=0
RETRY_COUNT=0
EOF
: >"$LOG_DIR/sketchybar"
plugin render
grep -q 'caffeinate label=狀態異常' "$LOG_DIR/sketchybar" \
  || fail 'impossible candidate phase did not render a warning'
rm -f "$STATE_DIR/caffeinate.pending"
pass 'candidate phases require a complete process identity'

printf 'PHASE=forged-marker\n' >"$STATE_DIR/caffeinate.pending"
: >"$DIAG_LOG"
plugin __recover__
grep -q 'event=recovery_begin pending=invalid phase=none' "$DIAG_LOG" \
  || fail 'invalid pending state lacked a fixed diagnostic marker'
! grep -q 'forged-marker' "$DIAG_LOG" \
  || fail 'invalid pending fields polluted the diagnostic log'
rm -f "$STATE_DIR/caffeinate.pending"
pass 'invalid state cannot forge diagnostic fields'

export TZ=America/Los_Angeles
set +e
spring=$(plugin __resolve-wall 2026-03-08 02:30 0)
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "spring DST gap was accepted as $spring"
fold_first=$(plugin __resolve-wall 2026-11-01 01:30 0)
fold_second=$(plugin __resolve-wall 2026-11-01 01:30 "$fold_first")
[ "$fold_second" -gt "$fold_first" ] || fail 'fall DST fold did not select the next occurrence'
assert_eq "$(date -r "$fold_first" '+%Y-%m-%d %H:%M')" '2026-11-01 01:30' \
  'first DST fold candidate does not round-trip'
assert_eq "$(date -r "$fold_second" '+%Y-%m-%d %H:%M')" '2026-11-01 01:30' \
  'second DST fold candidate does not round-trip'
unset TZ
pass 'DST gap rejects and fold selects the next occurrence'

plugin stop
assert_eq "$(process_count)" 0 'stop after corrupt pending fixtures retained an owner'
: >"$DIAG_LOG"
plugin __log_delayed__
first_log_time=$(sed -n '1s/^ts=\([0-9][0-9]*\).*/\1/p' "$DIAG_LOG")
second_log_time=$(sed -n '2s/^ts=\([0-9][0-9]*\).*/\1/p' "$DIAG_LOG")
[ "$second_log_time" -gt "$first_log_time" ] \
  || fail 'diagnostic timestamps did not advance within one invocation'
pass 'diagnostic timestamps preserve cross-second event order'
log_burst_started=$(now_ms)
plugin __log__ 20
log_burst_elapsed=$(($(now_ms) - log_burst_started))
assert_le "$log_burst_elapsed" 250 '20 diagnostic events exceeded 250ms'
pass "diagnostic event burst stays lightweight (${log_burst_elapsed}ms)"
/usr/bin/perl -e 'print "x" x 131050' >"$DIAG_LOG"
plugin __log__
[ "$(stat -f %z "$DIAG_LOG")" -le 131072 ] \
  || fail 'projected diagnostic append exceeded its size cap'
grep -q 'event=fixture key=value' "$DIAG_LOG" \
  || fail 'diagnostic rotation lost the triggering event'
pass 'diagnostic log enforces its size cap before append'
REAL_ROOT="$TEST_ROOT/real"
mkdir -p "$REAL_ROOT"
real_plugin "$REAL_ROOT" display-toggle
REAL_PID=$(sed -n 's/^PID=//p' "$REAL_ROOT/state/caffeinate.state")
kill -0 "$REAL_PID" 2>/dev/null || fail 'real caffeinate owner did not remain alive'
real_transition_started=$(now_ms)
real_plugin "$REAL_ROOT" display-toggle
real_transition_elapsed=$(($(now_ms) - real_transition_started))
assert_eq "$(sed -n 's/^DISPLAY=//p' "$REAL_ROOT/state/caffeinate.state")" 0 \
  'real replacement did not enter 10'
assert_le "$real_transition_elapsed" 3000 'real 11 -> 10 replacement exceeded 3000ms'
REAL_PID=$(sed -n 's/^PID=//p' "$REAL_ROOT/state/caffeinate.state")
real_plugin "$REAL_ROOT" stop
wait_for '! kill -0 '"$REAL_PID"' 2>/dev/null' 'real caffeinate owner was not stopped'
REAL_PID=""
pass 'production ps parser replaces and stops a real caffeinate owner within budget'

REAL_ROOT="$TEST_ROOT/real-legacy"
mkdir -p "$REAL_ROOT/legacy"
/usr/bin/caffeinate -i </dev/null >/dev/null 2>&1 &
REAL_PID=$!
legacy_real_start=$(/bin/ps -o lstart= -p "$REAL_PID")
cat >"$REAL_ROOT/legacy/caffeinate.state" <<EOF
PID=$REAL_PID
END=
MODE=forever
START=$legacy_real_start
EOF
: >"$REAL_ROOT/legacy/caffeinate.lock"
real_plugin "$REAL_ROOT" render
assert_eq "$(sed -n 's/^PID=//p' "$REAL_ROOT/state/caffeinate.state")" "$REAL_PID" \
  'real legacy owner was not adopted'
[ ! -e "$REAL_ROOT/legacy/caffeinate.state" ] || fail 'real legacy state remained after adoption'
real_plugin "$REAL_ROOT" stop
wait_for '! kill -0 '"$REAL_PID"' 2>/dev/null' 'real adopted legacy owner was not stopped'
REAL_PID=""
pass 'raw BSD ps legacy identity migrates without orphaning its owner'

mkdir "$TEST_ROOT/state-target"
ln -s "$TEST_ROOT/state-target/file" "$STATE_DIR/caffeinate.state"
set +e
plugin forever
rc=$?
set -e
[ "$rc" -ne 0 ] || fail 'symlink state path was accepted'
[ ! -e "$TEST_ROOT/state-target/file" ] || fail 'symlink state target was written'
assert_eq "$(process_count)" 0 'unsafe state path launched an owner before failing'
pass 'unsafe state paths fail closed'

set +e
CONFIG_DIR="$CONFIG_ROOT" "$PLUGIN" __test__ render >/dev/null 2>&1
rc=$?
set -e
assert_eq "$rc" 64 '__test__ accepted a missing isolated root'
pass 'test overrides require an isolated root'

grep -q 'click_script="$PLUGIN_DIR/apple.sh click"' "$CONFIG_ROOT/items/apple.sh" \
  || fail 'Apple click is not explicitly routed'
grep -q 'caffeinate.sh display-sleep' "$CONFIG_ROOT/items/apple.sh" \
  || fail 'display-sleep bypasses the owner'
grep -q 'label="关闭显示器"' "$CONFIG_ROOT/items/apple.sh" \
  || fail 'display menu label remains misleading'
grep -q 'click_script="$POPUP_OFF; $PLUGIN_DIR/apple.sh about"' "$CONFIG_ROOT/items/apple.sh" \
  || fail 'About opens before the Apple popup closes'
pass 'Apple item routes through the single owner'

if [ "$(process_count)" != 0 ]; then
  for leaked_owner in "$PROC_DIR"/*; do
    [ -f "$leaked_owner" ] || continue
    printf 'leaked fake owner: pid=%s argv=%s\n' \
      "${leaked_owner##*/}" "$(<"$leaked_owner")" >&2
  done
  fail 'test suite retained a fake caffeinate owner'
fi
pass 'test suite leaves no fake owner'
[ -z "$(find "$STATE_DIR" -name 'caffeinate.candidate.*.control' -print -quit)" ] \
  || fail 'candidate control files leaked after recovery'
pass 'candidate controls are fully reclaimed'

printf '1..%s\n' "$TEST_COUNT"
