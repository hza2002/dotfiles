#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SOURCE_HELPER="$CONFIG_ROOT/helper"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-installer-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
chmod 700 "$TEST_ROOT"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

fake_config="$TEST_ROOT/config"
fake_helper="$fake_config/helper"
fake_bin="$TEST_ROOT/bin"
runtime_dir="$TEST_ROOT/runtime"
service_state="$TEST_ROOT/service.state"
kickstarts="$TEST_ROOT/kickstarts"
activation_flag="$TEST_ROOT/activation.requested"
sketchybar_calls="$TEST_ROOT/sketchybar.calls"
installer_log="$TEST_ROOT/installer.log"

mkdir -m 700 "$fake_config" "$fake_helper" "$fake_bin"
cp "$SOURCE_HELPER/install.sh" "$SOURCE_HELPER/runtime.sh" \
  "$SOURCE_HELPER/helper-run.sh" "$fake_helper/"
printf '#!/bin/bash\n' > "$fake_config/sketchybarrc"
printf 'int main(void) { return 0; }\n' > "$fake_helper/helper.c"
printf 'fixture:\n\t@true\n' > "$fake_helper/makefile"
printf '#!/bin/bash\nprintf "old helper\\n"\n' > "$fake_helper/helper"
chmod 700 "$fake_helper/helper" "$fake_helper/install.sh" "$fake_helper/helper-run.sh"
old_hash="$(shasum -a 256 "$fake_helper/helper" | awk '{print $1}')"

printf '%s\n' \
  '#!/bin/bash' \
  'output=' \
  'for arg in "$@"; do' \
  '  case "$arg" in OUTPUT=*) output="${arg#OUTPUT=}" ;; esac' \
  'done' \
  '[ -n "$output" ] || exit 64' \
  'printf "%s\n" "#!/bin/bash" "trap '\''exit 143'\'' TERM HUP INT" "printf '\''ready\\n'\'' > \"\$SKETCHYBAR_HELPER_READY_FIFO\"" "while :; do sleep 1; done" > "$output"' \
  'chmod 700 "$output"' \
  > "$fake_bin/make"

printf '%s\n' \
  '#!/bin/bash' \
  'printf "%s: Mach-O 64-bit executable arm64\n" "$1"' \
  > "$fake_bin/file"

printf '%s\n' '#!/bin/bash' 'exit 0' > "$fake_bin/clang"

printf '%s\n' \
  '#!/bin/bash' \
  'if [ "${1:-}" = print ]; then' \
  '  read -r runs pid < "$SERVICE_STATE"' \
  '  printf "state = running\nruns = %s\npid = %s\n" "$runs" "$pid"' \
  '  exit 0' \
  'fi' \
  'if [ "${1:-}" = kickstart ]; then' \
  '  read -r runs pid < "$SERVICE_STATE"' \
  '  runs=$((runs + 1))' \
  '  pid=$((pid + 100))' \
  '  printf "%s %s\n" "$runs" "$pid" > "$SERVICE_STATE.next"' \
  '  mv -f "$SERVICE_STATE.next" "$SERVICE_STATE"' \
  '  printf "%s\n" "$*" >> "$KICKSTARTS"' \
  '  : > "$ACTIVATION_FLAG"' \
  '  exit 0' \
  'fi' \
  'exit 64' \
  > "$fake_bin/launchctl"

printf '%s\n' \
  '#!/bin/bash' \
  'printf "%s\n" "$*" >> "$SKETCHYBAR_CALLS"' \
  'exit 0' \
  > "$fake_bin/sketchybar"

printf '%s\n' \
  '#!/bin/bash' \
  'case "$*" in' \
  '  *lstart*) printf "Sun Jul 26 17:00:00 2026\n"; exit 0 ;;' \
  'esac' \
  'read -r runs service_pid < "$SERVICE_STATE"' \
  'wrapper_pid=$((service_pid + 1))' \
  'helper_pid=$((service_pid + 2))' \
  'printf "%s %s %s /bin/bash %s/helper-run.sh git.felix.helper\n" "$wrapper_pid" 1 "$service_pid" "$FAKE_HELPER"' \
  'printf "%s %s %s %s/helper git.felix.helper\n" "$helper_pid" "$wrapper_pid" "$service_pid" "$FAKE_HELPER"' \
  > "$fake_bin/ps"

chmod 700 "$fake_bin"/*
printf '1 100\n' > "$service_state"

export PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin"
export SERVICE_STATE="$service_state"
export KICKSTARTS="$kickstarts"
export ACTIVATION_FLAG="$activation_flag"
export SKETCHYBAR_CALLS="$sketchybar_calls"
export FAKE_HELPER="$fake_helper"
export SKETCHYBAR_HELPER_RUNTIME_DIR="$runtime_dir"

"$fake_helper/install.sh" 2> "$installer_log" &
installer_pid=$!

requested=false
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 \
         21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 \
         41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 \
         61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 \
         81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100; do
  if [ -e "$activation_flag" ]; then
    requested=true
    break
  fi
  sleep 0.02
done
$requested || fail "activation request was not observed"

kill -TERM "$installer_pid"
if wait "$installer_pid"; then
  fail "interrupted installer returned success"
fi

[ "$(shasum -a 256 "$fake_helper/helper" | awk '{print $1}')" = "$old_hash" ] \
  || fail "installed helper was not rolled back"
[ ! -e "$runtime_dir/install-in-progress" ] || fail "install marker remained"
[ ! -e "$runtime_dir/recovery.state" ] || fail "recovery state was not restored"
[ "$(wc -l < "$kickstarts" | tr -d ' ')" = 2 ] \
  || fail "activation and rollback did not request exactly two restarts"
grep -q -- '--hotload off' "$sketchybar_calls" || fail "hotload was not disabled"
grep -q -- '--hotload on' "$sketchybar_calls" || fail "hotload was not restored"
if ! grep -q 'event=rollback-complete restart=true' "$installer_log"; then
  sed -n '1,120p' "$installer_log" >&2
  fail "rollback completion was not diagnosed"
fi
find "$runtime_dir" -maxdepth 1 -type d -name 'install.*' | grep -q . \
  && fail "installer work directory remained"

printf 'ok - interrupted published install performs one verified rollback restart\n'
printf '1..1\n'
