#!/bin/bash
set -eu

HELPER_SOURCE="$(cd "$(dirname "$0")/../helper" && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-supervisor-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

fake_helper="$TEST_ROOT/helper"
fake_bin="$TEST_ROOT/bin"
mkdir "$fake_helper" "$fake_bin"
fake_helper="$(cd "$fake_helper" && pwd -P)"
cp "$HELPER_SOURCE/helper-run.sh" "$HELPER_SOURCE/start.sh" "$fake_helper/"
printf '%s\n' \
  '#!/bin/bash' \
  'if [ "${SIGNAL_READY:-false}" = true ]; then' \
  '  printf "ready\n" > "$SKETCHYBAR_HELPER_READY_FIFO"' \
  'fi' \
  'if [ "${WAIT_FOR_TERM:-false}" = true ]; then' \
  '  printf "%s\n" "$$" > "$CHILD_PID_FILE"' \
  '  trap "exit 143" TERM' \
  '  while :; do sleep 1; done' \
  'fi' \
  'if [ "${IGNORE_TERM:-false}" = true ]; then' \
  '  printf "%s\n" "$$" > "$CHILD_PID_FILE"' \
  '  trap "" TERM' \
  '  while :; do sleep 0.1; done' \
  'fi' \
  'exit 137' \
  > "$fake_helper/helper"
chmod +x "$fake_helper/helper" "$fake_helper/helper-run.sh" "$fake_helper/start.sh"

printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "$LAUNCHCTL_CALLS"\n' > "$fake_bin/launchctl"
chmod +x "$fake_bin/launchctl"
launchctl_calls="$TEST_ROOT/launchctl.calls"
: > "$launchctl_calls"
parent_fifo="$TEST_ROOT/parent-ready"
mkfifo "$parent_fifo"
exec 9<>"$parent_fifo"

# A fresh checkout builds the ignored helper binary before starting it.
fresh_helper="$TEST_ROOT/fresh-helper"
fresh_home="$TEST_ROOT/fresh-home"
fresh_child_pid="$TEST_ROOT/fresh-child.pid"
mkdir -p "$fresh_helper" "$fresh_home"
cp "$HELPER_SOURCE/helper-run.sh" "$HELPER_SOURCE/start.sh" "$fresh_helper/"
cat > "$fresh_helper/makefile" <<'MAKEFILE'
.PHONY: helper
helper:
	@cp helper.template helper.new
	@chmod +x helper.new
	@mv helper.new helper
MAKEFILE
cat > "$fresh_helper/helper.template" <<'HELPER'
#!/bin/bash
printf '%s\n' "$$" > "$FRESH_CHILD_PID"
printf 'ready\n' > "$SKETCHYBAR_HELPER_READY_FIFO"
trap 'exit 0' TERM
while :; do sleep 0.1; done
HELPER
chmod +x "$fresh_helper/helper-run.sh" "$fresh_helper/start.sh"
HOME="$fresh_home" FRESH_CHILD_PID="$fresh_child_pid" "$fresh_helper/start.sh"
[ -x "$fresh_helper/helper" ] || fail "fresh checkout did not build the helper"
for _ in {1..20}; do [ -s "$fresh_child_pid" ] && break; sleep 0.05; done
[ -s "$fresh_child_pid" ] || fail "freshly built helper did not start"
fresh_child="$(cat "$fresh_child_pid")"
fresh_wrapper="$(ps -o ppid= -p "$fresh_child" | tr -d ' ')"
kill -TERM "$fresh_wrapper"
for _ in {1..20}; do kill -0 "$fresh_wrapper" 2>/dev/null || break; sleep 0.05; done
kill -0 "$fresh_wrapper" 2>/dev/null && fail "fresh helper wrapper survived cleanup"
printf 'ok - fresh checkout builds the helper\n'

# An immediate startup failure must not create a service restart loop.
PATH="$fake_bin:$PATH" HOME="$TEST_ROOT" LAUNCHCTL_CALLS="$launchctl_calls" \
  SKETCHYBAR_HELPER_READY_FIFO="$parent_fifo" \
  "$fake_helper/helper-run.sh" git.felix.helper 9>&- \
  && fail "helper failure returned success"
[ ! -s "$launchctl_calls" ] || fail "cold-start failure restarted SketchyBar"
printf 'ok - cold-start failure stays failed\n'

# A ready helper gets one automatic paired restart.
date_calls="$TEST_ROOT/date.calls"
: > "$date_calls"
printf '%s\n' \
  '#!/bin/bash' \
  'count="$(wc -l < "$DATE_CALLS" | tr -d " ")"' \
  'printf "call\n" >> "$DATE_CALLS"' \
  'if [ "$count" = 0 ]; then printf "0\n"; else printf "%s\n" "${DATE_END:-1}"; fi' \
  > "$fake_bin/date"
chmod +x "$fake_bin/date"

mkdir -p "$TEST_ROOT/Library/Caches/sketchybar"
PATH="$fake_bin:$PATH" HOME="$TEST_ROOT" DATE_CALLS="$date_calls" \
  LAUNCHCTL_CALLS="$launchctl_calls" \
  SIGNAL_READY=true SKETCHYBAR_HELPER_READY_FIFO="$parent_fifo" \
  "$fake_helper/helper-run.sh" git.felix.helper 9>&- \
  && fail "helper failure returned success"
[ "$(wc -l < "$launchctl_calls" | tr -d ' ')" = 1 ] \
  || fail "ready helper failure did not restart SketchyBar once"
grep -q 'kickstart -k gui/.*/homebrew.mxcl.sketchybar' "$launchctl_calls" \
  || fail "unexpected recovery command"
printf 'ok - ready failure restarts the pair\n'

# A repeated failure is suppressed until the helper has stayed healthy long
# enough to reset the guard.
: > "$date_calls"
PATH="$fake_bin:$PATH" HOME="$TEST_ROOT" DATE_CALLS="$date_calls" \
  LAUNCHCTL_CALLS="$launchctl_calls" SIGNAL_READY=true \
  SKETCHYBAR_HELPER_READY_FIFO="$parent_fifo" \
  "$fake_helper/helper-run.sh" git.felix.helper 9>&- \
  && fail "helper failure returned success"
[ "$(wc -l < "$launchctl_calls" | tr -d ' ')" = 1 ] \
  || fail "repeated failure bypassed recovery guard"
printf 'ok - repeated failure is bounded\n'

: > "$date_calls"
PATH="$fake_bin:$PATH" HOME="$TEST_ROOT" DATE_CALLS="$date_calls" DATE_END=301 \
  LAUNCHCTL_CALLS="$launchctl_calls" SIGNAL_READY=true \
  SKETCHYBAR_HELPER_READY_FIFO="$parent_fifo" \
  "$fake_helper/helper-run.sh" git.felix.helper 9>&- \
  && fail "helper failure returned success"
[ "$(wc -l < "$launchctl_calls" | tr -d ' ')" = 2 ] \
  || fail "healthy interval did not reset recovery guard"
printf 'ok - healthy interval resets recovery guard\n'

# TERM sent only to the ready child still invalidates SketchyBar's cached port
# and must use the bounded recovery path.
term_home="$TEST_ROOT/term-home"
mkdir -p "$term_home/Library/Caches/sketchybar"
term_calls="$TEST_ROOT/term-launchctl.calls"
child_pid_file="$TEST_ROOT/child.pid"
: > "$term_calls"
: > "$date_calls"
PATH="$fake_bin:$PATH" HOME="$term_home" DATE_CALLS="$date_calls" \
  LAUNCHCTL_CALLS="$term_calls" SIGNAL_READY=true WAIT_FOR_TERM=true \
  CHILD_PID_FILE="$child_pid_file" SKETCHYBAR_HELPER_READY_FIFO="$parent_fifo" \
  "$fake_helper/helper-run.sh" git.felix.helper 9>&- &
wrapper_pid=$!
IFS= read -r -t 2 _ <&9 || fail "ready child did not signal"
for _ in {1..20}; do [ -s "$child_pid_file" ] && break; sleep 0.05; done
child_pid="$(cat "$child_pid_file")"
kill -TERM "$child_pid"
wait "$wrapper_pid" 2>/dev/null || true
[ "$(wc -l < "$term_calls" | tr -d ' ')" = 1 ] \
  || fail "direct child TERM did not restart the pair"
printf 'ok - direct child TERM restarts the pair\n'

# A helper that neither becomes ready nor honors TERM must not hold the startup
# lock forever.
stubborn_home="$TEST_ROOT/stubborn-home"
stubborn_pid_file="$TEST_ROOT/stubborn-child.pid"
mkdir -p "$stubborn_home"
HOME="$stubborn_home" IGNORE_TERM=true CHILD_PID_FILE="$stubborn_pid_file" \
  "$fake_helper/start.sh" &
start_pid=$!
for _ in {1..160}; do
  kill -0 "$start_pid" 2>/dev/null || break
  sleep 0.05
done
if kill -0 "$start_pid" 2>/dev/null; then
  kill -KILL "$start_pid" 2>/dev/null || true
  fail "stubborn helper left startup blocked"
fi
wait "$start_pid" 2>/dev/null && fail "stubborn helper startup returned success"
stubborn_pid="$(cat "$stubborn_pid_file")"
kill -0 "$stubborn_pid" 2>/dev/null && fail "stubborn helper survived cleanup"
printf 'ok - startup cleanup is bounded\n'

# A detached pair outside SketchyBar's process group must never be adopted.
printf '%s\n' \
  '#!/bin/bash' \
  'printf "%s\n" "$*" >> "$PGREP_CALLS"' \
  'case "$*" in' \
  '  *"-x sketchybar"*) printf "100\n" ;;' \
  '  *) /usr/bin/pgrep "$@" ;;' \
  'esac' \
  > "$fake_bin/pgrep"
printf '%s\n' \
  '#!/bin/bash' \
  'case "$*" in' \
  '  *"pgid="*"-p 100") printf "100\n" ;;' \
  '  *) /bin/ps "$@" ;;' \
  'esac' \
  > "$fake_bin/ps"
chmod +x "$fake_bin/pgrep"
chmod +x "$fake_bin/ps"
orphan_home="$TEST_ROOT/orphan-home"
orphan_calls="$TEST_ROOT/orphan-launchctl.calls"
pgrep_calls="$TEST_ROOT/pgrep.calls"
mkdir -p "$orphan_home"
: > "$orphan_calls"
: > "$pgrep_calls"
PATH="$fake_bin:$PATH" HOME="$orphan_home" DATE_CALLS="$date_calls" \
  SIGNAL_READY=true WAIT_FOR_TERM=true \
  CHILD_PID_FILE="$TEST_ROOT/detached-child.pid" \
  SKETCHYBAR_HELPER_READY_FIFO="$parent_fifo" \
  "$fake_helper/helper-run.sh" git.felix.helper 9>&- &
detached_wrapper_pid=$!
IFS= read -r -t 2 _ <&9 || fail "detached helper did not become ready"
if PATH="$fake_bin:$PATH" HOME="$orphan_home" LAUNCHCTL_CALLS="$orphan_calls" \
  PGREP_CALLS="$pgrep_calls" \
  "$fake_helper/start.sh"; then
  fail "detached helper pair was adopted"
fi
wait "$detached_wrapper_pid" 2>/dev/null || true
kill -0 "$detached_wrapper_pid" 2>/dev/null \
  && fail "detached helper wrapper survived recovery"
[ "$(wc -l < "$orphan_calls" | tr -d ' ')" = 1 ] \
  || fail "orphan helper did not restart SketchyBar"
grep -q 'kickstart -k gui/.*/homebrew.mxcl.sketchybar' "$orphan_calls" \
  || fail "orphan recovery used an unexpected command"
if grep -v '^-U [0-9][0-9]* ' "$pgrep_calls" | grep -q .; then
  fail "process lookup was not restricted to the current UID"
fi
printf 'ok - detached pair forces paired restart\n'

printf '1..8\n'
