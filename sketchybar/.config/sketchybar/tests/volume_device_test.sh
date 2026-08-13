#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PLUGIN="$CONFIG_ROOT/plugins/volume.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

classify() {
  local profile_json='{}'
  [ "$#" -lt 3 ] || profile_json="$3"
  CONFIG_DIR="$CONFIG_ROOT" SENDER=test.device_class \
    DEVICE_UID="$1" DEVICE_NAME="$2" \
    DEVICE_PROFILE_JSON="$profile_json" \
    "$PLUGIN"
}

assert_class() {
  local expected="$1"
  shift
  [ "$(classify "$@")" = "$expected" ] || fail "expected $expected"
}

audio_profile() {
  jq -cn --arg name "$1" --arg transport "$2" '
    {SPAudioDataType: [{_items: [{_name: $name, coreaudio_device_output: 2,
      coreaudio_device_transport: $transport}]}]}
  '
}

bluetooth_profile() {
  jq -cn --arg address "$1" --arg minor "$2" --arg vendor "$3" --argjson airpods "$4" '
    {SPBluetoothDataType: [{device_connected: [{device: ({
      device_address: $address, device_minorType: $minor, device_vendorID: $vendor
    } + if $airpods then {device_batteryLevelLeft: "80%", device_batteryLevelRight: "75%"} else {} end)}]}]}
  '
}

combined_profile() {
  jq -cn --argjson audio "$1" --argjson bluetooth "$2" '$audio + $bluetooth'
}

assert_class speaker BuiltInSpeakerDevice Speakers
assert_class headphones BuiltInHeadphoneOutputDevice Headphones

display_audio="$(audio_profile Monitor coreaudio_device_type_displayport)"
assert_class display display-uid Monitor "$display_audio"

usb_audio="$(audio_profile DAC coreaudio_device_type_usb)"
assert_class usb usb-uid DAC "$usb_audio"

virtual_audio="$(audio_profile Virtual coreaudio_device_type_virtual)"
assert_class virtual virtual-uid Virtual "$virtual_audio"

bluetooth_audio="$(audio_profile Pods coreaudio_device_type_bluetooth)"
airpods_bluetooth="$(bluetooth_profile 'AA:BB:CC:DD:EE:FF' Headphones 0x004C true)"
airpods_profile="$(combined_profile "$bluetooth_audio" "$airpods_bluetooth")"
assert_class airpods 'AA-BB-CC-DD-EE-FF:output' Pods "$airpods_profile"

headphones_bluetooth="$(bluetooth_profile '11:22:33:44:55:66' Headphones 0x1234 false)"
headphones_profile="$(combined_profile "$bluetooth_audio" "$headphones_bluetooth")"
assert_class bluetooth_headphones '11-22-33-44-55-66:output' Pods \
  "$headphones_profile"

speaker_bluetooth="$(bluetooth_profile '22:33:44:55:66:77' Speaker 0x1234 false)"
speaker_profile="$(combined_profile "$bluetooth_audio" "$speaker_bluetooth")"
assert_class bluetooth_speaker '22-33-44-55-66-77:output' Pods \
  "$speaker_profile"

assert_class unknown '33-44-55-66-77-88:output' Pods "$bluetooth_audio"
assert_class unknown unknown-uid Unknown '{}'

printf 'ok - audio output device classification\n'

fake_switch="$TEST_ROOT/SwitchAudioSource"
fake_profiler="$TEST_ROOT/system_profiler"
switch_calls="$TEST_ROOT/switch.calls"
profiler_calls="$TEST_ROOT/profiler.calls"

cat > "$fake_switch" <<'SWITCH'
#!/bin/bash
count=0
[ ! -f "$SWITCH_CALLS" ] || count="$(cat "$SWITCH_CALLS")"
count=$((count + 1))
printf '%s\n' "$count" > "$SWITCH_CALLS"
if [ -n "${SWITCH_SECOND_UID:-}" ] && [ "$count" -gt 1 ]; then
  uid="$SWITCH_SECOND_UID"
else
  uid="$SWITCH_UID"
fi
jq -cn --arg uid "$uid" --arg name "$SWITCH_NAME" '{uid: $uid, name: $name}'
SWITCH

cat > "$fake_profiler" <<'PROFILER'
#!/bin/bash
printf '%s\n' "$*" >> "$PROFILER_CALLS"
printf '%s\n' "$PROFILER_JSON"
PROFILER
chmod +x "$fake_switch" "$fake_profiler"

current_class() {
  local test_home="$1" uid="$2" name="$3" profile="$4" second_uid="${5:-}"
  : > "$switch_calls"
  : > "$profiler_calls"
  HOME="$test_home" CONFIG_DIR="$CONFIG_ROOT" SENDER=test.current_device_class \
    SWITCH_AUDIO_SOURCE_BIN="$fake_switch" SYSTEM_PROFILER_BIN="$fake_profiler" \
    SWITCH_CALLS="$switch_calls" PROFILER_CALLS="$profiler_calls" \
    SWITCH_UID="$uid" SWITCH_SECOND_UID="$second_uid" SWITCH_NAME="$name" \
    PROFILER_JSON="$profile" "$PLUGIN"
}

cache_home="$TEST_ROOT/cache-home"
cache_dir="$cache_home/Library/Caches/sketchybar"
mkdir -p "$cache_dir"
now="$(date +%s)"
printf '1\tusb-uid\tusb\t%s\n' "$((now + 60))" > "$cache_dir/volume-device"
[ "$(current_class "$cache_home" usb-uid DAC '{}')" = usb ] || fail "positive cache miss"
[ ! -s "$profiler_calls" ] || fail "positive cache unexpectedly ran profiler"
printf 'ok - positive device cache hit\n'

negative_home="$TEST_ROOT/negative-home"
[ "$(current_class "$negative_home" unknown-uid Unknown '{}')" = unknown ] \
  || fail "unknown device classification failed"
grep -Fx -- '-timeout 2 SPAudioDataType SPBluetoothDataType -json' "$profiler_calls" >/dev/null \
  || fail "profiler was not bounded and combined"
negative_cache="$negative_home/Library/Caches/sketchybar/volume-device"
IFS=$'\t' read -r version cached_uid cached_class expires < "$negative_cache"
[ "$version:$cached_uid:$cached_class" = '1:unknown-uid:unknown' ] \
  || fail "unknown cache record is invalid"
[ "$expires" -ge "$((now + 1))" ] && [ "$expires" -le "$((now + 7))" ] \
  || fail "unknown cache TTL is not short"
[ "$(current_class "$negative_home" unknown-uid Unknown '{}')" = unknown ] \
  || fail "unknown cache hit failed"
[ ! -s "$profiler_calls" ] || fail "unknown cache unexpectedly reran profiler"
printf 'ok - unknown device uses a short negative cache\n'

invalid_home="$TEST_ROOT/invalid-home"
invalid_dir="$invalid_home/Library/Caches/sketchybar"
mkdir -p "$invalid_dir"
printf '1\tusb-uid\tmalicious\t%s\n' "$((now + 60))" > "$invalid_dir/volume-device"
usb_profile="$(audio_profile DAC coreaudio_device_type_usb)"
[ "$(current_class "$invalid_home" usb-uid DAC "$usb_profile")" = usb ] \
  || fail "invalid cache did not refresh"
[ -s "$profiler_calls" ] || fail "invalid cache bypassed profiler"
printf 'ok - invalid cache classes are rejected\n'

race_home="$TEST_ROOT/race-home"
if current_class "$race_home" usb-uid DAC "$usb_profile" display-uid >/dev/null; then
  fail "device change during classification returned stale data"
fi
[ ! -e "$race_home/Library/Caches/sketchybar/volume-device" ] \
  || fail "device change cached stale data"
printf 'ok - device changes discard stale classification\n'
