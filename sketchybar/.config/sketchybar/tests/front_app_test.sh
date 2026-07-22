#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$SCRIPT_DIR/../plugins/front_app.sh"
GENERIC_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin"

cat >"$TMP_DIR/bin/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$SKETCHYBAR_ARGS_OUT"
EOF
chmod +x "$TMP_DIR/bin/sketchybar"

cat >"$TMP_DIR/bin/osascript" <<'EOF'
#!/usr/bin/env bash
if [ -n "${STUB_OSASCRIPT_STATUS:-}" ]; then
  exit "$STUB_OSASCRIPT_STATUS"
fi
printf '%s\n' "${STUB_OSASCRIPT_BUNDLE_ID:-}"
EOF
chmod +x "$TMP_DIR/bin/osascript"

cat >"$TMP_DIR/bin/lsappinfo" <<'EOF'
#!/usr/bin/env bash
if [ -n "${STUB_LSAPPINFO_STATUS:-}" ]; then
  exit "$STUB_LSAPPINFO_STATUS"
fi

case "$1" in
  front)
    printf 'ASN:0x0-0x12345:\n'
    ;;
  info)
    printf '%s\n' "${STUB_LSAPPINFO_OUTPUT:-}"
    ;;
esac
EOF
chmod +x "$TMP_DIR/bin/lsappinfo"

fail() {
  printf 'front_app_test: %s\n' "$*" >&2
  exit 1
}

run_plugin() {
  local info="$1"
  local lsappinfo_output="${2:-}"
  local osascript_bundle_id="${3:-}"
  local lsappinfo_status="${4:-}"
  local osascript_status="${5:-}"
  SKETCHYBAR_ARGS_OUT="$TMP_DIR/sketchybar.args" \
  STUB_LSAPPINFO_OUTPUT="$lsappinfo_output" \
  STUB_OSASCRIPT_BUNDLE_ID="$osascript_bundle_id" \
  STUB_LSAPPINFO_STATUS="$lsappinfo_status" \
  STUB_OSASCRIPT_STATUS="$osascript_status" \
  PATH="$TMP_DIR/bin:$PATH" \
  SENDER="front_app_switched" \
  NAME="front_app" \
  INFO="$info" \
  SKETCHYBAR_BIN="sketchybar" \
  LSAPPINFO_BIN="lsappinfo" \
    bash "$PLUGIN"
}

assert_arg() {
  local expected="$1"
  grep -Fx -- "$expected" "$TMP_DIR/sketchybar.args" >/dev/null \
    || fail "missing expected argument: $expected"
}

assert_no_arg_matching() {
  local pattern="$1"
  if grep -E -- "$pattern" "$TMP_DIR/sketchybar.args" >/dev/null; then
    fail "unexpected argument matching: $pattern"
  fi
}

run_plugin "Code" $'"CFBundleIdentifier"="com.microsoft.VSCode"\n"LSDisplayName"="Visual Studio Code"' "ignored.bundle.id"
assert_arg "icon.background.image=app.com.microsoft.VSCode"
assert_arg "label=Visual Studio Code"
assert_arg "icon.background.drawing=on"
assert_no_arg_matching "sketchybar-app-font"

run_plugin "Ghostty" '"CFBundleIdentifier"="com.mitchellh.ghostty"' "ignored.bundle.id"
assert_arg "icon.background.image=app.com.mitchellh.ghostty"
assert_arg "label=Ghostty"
assert_arg "icon.background.drawing=on"
assert_no_arg_matching "sketchybar-app-font"

run_plugin "Preview" '"LSDisplayName"="Stale App Name"' "com.apple.Preview"
assert_arg "icon.background.image=app.com.apple.Preview"
assert_arg "label=Preview"
assert_arg "icon.background.drawing=on"
assert_no_arg_matching "Stale App Name"
assert_no_arg_matching "sketchybar-app-font"

run_plugin "Safari" "" "com.apple.Safari" "1"
assert_arg "icon.background.image=app.com.apple.Safari"
assert_arg "label=Safari"
assert_arg "icon.background.drawing=on"
assert_no_arg_matching "sketchybar-app-font"

run_plugin "Broken" "not parseable" "" "" "1"
assert_arg "icon.background.image=$GENERIC_ICON"
assert_arg "label=Broken"
assert_arg "icon.background.drawing=on"
assert_no_arg_matching "sketchybar-app-font"

run_plugin "" "" "" "1" "1"
assert_arg "icon.background.image=$GENERIC_ICON"
assert_arg "label=未知"
assert_arg "icon.background.drawing=on"
assert_no_arg_matching "sketchybar-app-font"

rm -f "$TMP_DIR/sketchybar.args"
SKETCHYBAR_ARGS_OUT="$TMP_DIR/sketchybar.args" \
PATH="$TMP_DIR/bin:$PATH" \
SENDER="routine" \
NAME="front_app" \
INFO="Safari" \
SKETCHYBAR_BIN="sketchybar" \
LSAPPINFO_BIN="lsappinfo" \
  bash "$PLUGIN"
[ ! -e "$TMP_DIR/sketchybar.args" ] || fail "non-front_app event should not call sketchybar"

printf 'front_app_test: ok\n'
