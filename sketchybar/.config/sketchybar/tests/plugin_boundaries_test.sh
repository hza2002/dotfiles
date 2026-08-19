#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-plugin-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

fake_bin="$TEST_ROOT/bin"
mkdir "$fake_bin"

# Volume deltas are external event input. Only canonical values from -10 to 10
# may reach AppleScript.
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "$OSASCRIPT_CALLS"\n' > "$fake_bin/osascript"
chmod +x "$fake_bin/osascript"
volume_calls="$TEST_ROOT/volume.calls"
: > "$volume_calls"

for delta in - 1-2 --1 08 11 -11 999999999999999999999; do
  PATH="$fake_bin:$PATH" OSASCRIPT_CALLS="$volume_calls" \
    SENDER=mouse.scrolled SCROLL_DELTA="$delta" MODIFIER=ctrl INFO= \
    "$CONFIG_ROOT/plugins/volume_click.sh"
done
[ ! -s "$volume_calls" ] || fail "invalid volume delta reached osascript"

PATH="$fake_bin:$PATH" OSASCRIPT_CALLS="$volume_calls" \
  SENDER=mouse.scrolled SCROLL_DELTA=-10 MODIFIER=ctrl INFO= \
  "$CONFIG_ROOT/plugins/volume_click.sh"
[ "$(wc -l < "$volume_calls" | tr -d ' ')" = 1 ] \
  || fail "valid volume delta was rejected"
printf 'ok - bounded volume input\n'

# Slider percentages become AppleScript source and must be canonical integers.
slider_calls="$TEST_ROOT/volume-slider.calls"
: > "$slider_calls"
for percentage in "" -1 1.5 101 00 01 999999999999999999999 \
  $'0\ndo shell script "false"'; do
  PATH="$fake_bin:$PATH" OSASCRIPT_CALLS="$slider_calls" \
    SENDER=mouse.clicked PERCENTAGE="$percentage" \
    "$CONFIG_ROOT/plugins/volume.sh"
done
[ ! -s "$slider_calls" ] || fail "invalid slider percentage reached osascript"

for percentage in 0 42 100; do
  PATH="$fake_bin:$PATH" OSASCRIPT_CALLS="$slider_calls" \
    SENDER=mouse.clicked PERCENTAGE="$percentage" \
    "$CONFIG_ROOT/plugins/volume.sh"
done
[ "$(cat "$slider_calls")" = $'-e set volume output volume 0\n-e set volume output volume 42\n-e set volume output volume 100' ] \
  || fail "valid slider percentage was rejected or altered"
printf 'ok - bounded volume slider input\n'

# App counts come from yabai events. Reject one oversized count before invoking
# either icon_map or SketchyBar.
printf '#!/bin/bash\n[ -n "${SKETCHYBAR_CALLS:-}" ] && printf "%%s\\n" "$*" >> "$SKETCHYBAR_CALLS"\nexit 0\n' \
  > "$fake_bin/sketchybar"
chmod +x "$fake_bin/sketchybar"
yabai_calls="$TEST_ROOT/yabai.calls"
: > "$yabai_calls"

PATH="$fake_bin:$PATH" SKETCHYBAR_CALLS="$yabai_calls" \
  CONFIG_DIR="$CONFIG_ROOT" NAME=yabai SENDER=space_windows_change \
  INFO='{"space":1,"apps":{"Ghostty":17}}' \
  "$CONFIG_ROOT/plugins/yabai.sh"
[ ! -s "$yabai_calls" ] || fail "oversized yabai count reached sketchybar"

long_app="$(printf 'a%.0s' {1..257})"
long_app_info="$(jq -cn --arg app "$long_app" '{space: 1, apps: {($app): 1}}')"
PATH="$fake_bin:$PATH" SKETCHYBAR_CALLS="$yabai_calls" \
  CONFIG_DIR="$CONFIG_ROOT" NAME=yabai SENDER=space_windows_change \
  INFO="$long_app_info" "$CONFIG_ROOT/plugins/yabai.sh"
[ ! -s "$yabai_calls" ] || fail "oversized yabai app name reached sketchybar"

PATH="$fake_bin:$PATH" SKETCHYBAR_CALLS="$yabai_calls" \
  CONFIG_DIR="$CONFIG_ROOT" NAME=yabai SENDER=space_windows_change \
  INFO='{"space":999999999999999999,"apps":{}}' \
  "$CONFIG_ROOT/plugins/yabai.sh"
[ ! -s "$yabai_calls" ] || fail "oversized yabai space reached sketchybar"
printf 'ok - bounded yabai input\n'

# A burst of stale Wi-Fi events may start at most one public-IP request.
printf '%s\n' \
  '#!/bin/bash' \
  'printf "%s\n" "$*" >> "$CURL_CALLS"' \
  'sleep 0.2' \
  'printf "%s\n" "${CURL_RESPONSE:-{\"success\":true,\"ip\":\"203.0.113.1\",\"country\":\"Test\",\"country_code\":\"TT\"}}"' \
  > "$fake_bin/curl"
printf '#!/bin/bash\nprintf "IP address: 192.0.2.1\\nRouter: 192.0.2.254\\n"\n' \
  > "$fake_bin/networksetup"
chmod +x "$fake_bin/curl" "$fake_bin/networksetup"

wifi_root="$TEST_ROOT/wifi"
mkdir "$wifi_root"
wifi_calls="$TEST_ROOT/wifi.calls"
: > "$wifi_calls"

for _ in {1..20}; do
  PATH="$fake_bin:$PATH" HOME="$wifi_root" CURL_CALLS="$wifi_calls" \
    CONFIG_DIR="$CONFIG_ROOT" NAME=wifi SENDER=routine INFO=test \
    "$CONFIG_ROOT/plugins/wifi.sh" &
done
wait
sleep 1
[ "$(wc -l < "$wifi_calls" | tr -d ' ')" = 1 ] \
  || fail "Wi-Fi refresh spawned multiple curl requests"
grep -Fq 'https://ipwho.is/?fields=success,ip,country,country_code' "$wifi_calls" \
  || fail "Wi-Fi public-IP request did not use the HTTPS endpoint"
! grep -Fq 'http://' "$wifi_calls" \
  || fail "Wi-Fi public-IP request used plaintext HTTP"

cache_file="$wifi_root/Library/Caches/sketchybar/wifi-public.cache"
jq -e '.query == "203.0.113.1" and .country == "Test" and .countryCode == "TT"' \
  "$cache_file" >/dev/null || fail "valid Wi-Fi response was not cached"
printf 'ok - serialized Wi-Fi refresh\n'

error_home="$TEST_ROOT/error-home"
mkdir "$error_home"
PATH="$fake_bin:$PATH" HOME="$error_home" CURL_CALLS="$wifi_calls" \
  CURL_RESPONSE='{"success":false,"message":"Rate limit exceeded"}' \
  CONFIG_DIR="$CONFIG_ROOT" NAME=wifi SENDER=routine INFO=test \
  "$CONFIG_ROOT/plugins/wifi.sh"
sleep 0.5
[ ! -e "$error_home/Library/Caches/sketchybar/wifi-public.cache" ] \
  || fail "Wi-Fi API error response was cached"
printf 'ok - Wi-Fi API errors are rejected\n'

unsafe_home="$TEST_ROOT/unsafe-home"
mkdir -p "$unsafe_home/Library/Caches" "$TEST_ROOT/cache-target"
ln -s "$TEST_ROOT/cache-target" "$unsafe_home/Library/Caches/sketchybar"
PATH="$fake_bin:$PATH" HOME="$unsafe_home" CURL_CALLS="$wifi_calls" \
  CONFIG_DIR="$CONFIG_ROOT" NAME=wifi SENDER=routine INFO=test \
  "$CONFIG_ROOT/plugins/wifi.sh" && fail "symlink cache directory was accepted"
printf 'ok - private Wi-Fi cache path\n'

bad_cache_home="$TEST_ROOT/bad-cache-home"
mkdir -p "$bad_cache_home/Library/Caches/sketchybar/wifi-public.cache"
calls_before="$(wc -l < "$wifi_calls" | tr -d ' ')"
PATH="$fake_bin:$PATH" HOME="$bad_cache_home" CURL_CALLS="$wifi_calls" \
  CONFIG_DIR="$CONFIG_ROOT" NAME=wifi SENDER=routine INFO=test \
  "$CONFIG_ROOT/plugins/wifi.sh"
sleep 0.2
calls_after="$(wc -l < "$wifi_calls" | tr -d ' ')"
[ "$calls_after" = "$calls_before" ] || fail "invalid cache path triggered curl"
[ -z "$(find "$bad_cache_home/Library/Caches/sketchybar/wifi-public.cache" -type f -print -quit)" ] \
  || fail "invalid cache path accumulated temporary files"
printf 'ok - invalid Wi-Fi cache fails closed\n'

printf '1..7\n'
