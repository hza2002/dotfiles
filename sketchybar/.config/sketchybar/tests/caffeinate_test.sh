#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-caffeinate-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

fake_bin="$TEST_ROOT/bin"
test_home="$TEST_ROOT/home"
cache_dir="$test_home/Library/Caches/sketchybar"
mkdir -p "$fake_bin" "$cache_dir"
printf '#!/bin/bash\nexit 0\n' > "$fake_bin/sketchybar"
chmod +x "$fake_bin/sketchybar"

# A stale PID that now belongs to another command must never be signalled.
printf 'PID=%s\nEND=\nMODE=forever\nSTART=stale\n' "$$" > "$cache_dir/caffeinate.state"
PATH="$fake_bin:$PATH" HOME="$test_home" CONFIG_DIR="$CONFIG_ROOT" \
  "$CONFIG_ROOT/plugins/caffeinate.sh" render
[ ! -e "$cache_dir/caffeinate.state" ] || fail "stale PID state was retained"
kill -0 $$ || fail "stale state killed an unrelated process"
printf 'ok - stale PID fails closed\n'

# Even the same command line is not enough authority when the process start
# identity differs.
printf '%s\n' \
  '#!/bin/bash' \
  'case "$*" in' \
  '  *"command="*) printf "/usr/bin/caffeinate -i\n" ;;' \
  '  *"lstart="*) printf "new process identity\n" ;;' \
  'esac' \
  > "$fake_bin/ps"
chmod +x "$fake_bin/ps"
printf 'PID=%s\nEND=\nMODE=forever\nSTART=old process identity\n' "$$" \
  > "$cache_dir/caffeinate.state"
PATH="$fake_bin:$PATH" HOME="$test_home" CONFIG_DIR="$CONFIG_ROOT" \
  "$CONFIG_ROOT/plugins/caffeinate.sh" render
[ ! -e "$cache_dir/caffeinate.state" ] || fail "reused PID state was retained"
kill -0 $$ || fail "reused PID killed an unrelated caffeinate"
printf 'ok - PID identity is verified\n'

# Arithmetic-looking CLI input is rejected before process launch.
set +e
PATH="$fake_bin:$PATH" HOME="$test_home" CONFIG_DIR="$CONFIG_ROOT" \
  "$CONFIG_ROOT/plugins/caffeinate.sh" hours '1+1'
rc=$?
set -e
[ "$rc" -eq 64 ] || fail "invalid duration was accepted"
[ ! -e "$cache_dir/caffeinate.state" ] || fail "invalid duration wrote state"
printf 'ok - duration input is finite\n'

unsafe_home="$TEST_ROOT/unsafe-home"
mkdir -p "$unsafe_home/Library/Caches" "$TEST_ROOT/cache-target"
ln -s "$TEST_ROOT/cache-target" "$unsafe_home/Library/Caches/sketchybar"
if PATH="$fake_bin:$PATH" HOME="$unsafe_home" CONFIG_DIR="$CONFIG_ROOT" \
  "$CONFIG_ROOT/plugins/caffeinate.sh" render; then
  fail "symlink cache directory was accepted"
fi
printf 'ok - private caffeinate state path\n'

rm -f "$fake_bin/ps"
mkdir "$cache_dir/caffeinate.state"
if PATH="$fake_bin:$PATH" HOME="$test_home" CONFIG_DIR="$CONFIG_ROOT" \
  "$CONFIG_ROOT/plugins/caffeinate.sh" forever; then
  fail "directory state path was accepted"
fi
[ -z "$(find "$cache_dir/caffeinate.state" -type f -print -quit)" ] \
  || fail "directory state accumulated nested files"
printf 'ok - invalid state type fails closed\n'

printf '1..5\n'
