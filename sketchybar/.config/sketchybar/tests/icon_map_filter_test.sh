#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
FILTER="$CONFIG_ROOT/scripts/filter_icon_map.py"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

input="$TEST_ROOT/upstream.sh"
output="$TEST_ROOT/filtered.sh"
cat > "$input" <<'MAP'
#!/usr/bin/env bash
### START-OF-ICON-MAP
function __icon_map() {
  case "$1" in
    "Code" | "Code - Insiders")
      icon_result=":code:"
      ;;
    "Electron")
      icon_result=":electron:"
      ;;
    "Definitely Not Installed")
      icon_result=":missing:"
      ;;
    *)
      icon_result=":default:"
      ;;
  esac
}
### END-OF-ICON-MAP
printf 'upstream footer\n'
MAP
input_hash="$(shasum -a 256 "$input" | awk '{print $1}')"

HOME="$TEST_ROOT/home" /usr/bin/python3 "$FILTER" --input "$input" --output "$output" >/dev/null
[ "$(shasum -a 256 "$input" | awk '{print $1}')" = "$input_hash" ] \
  || fail "filter modified its upstream input"
/bin/bash -n "$output" || fail "filtered map is not valid bash"
chmod +x "$output"
[ "$($output --batch Code Electron 'Definitely Not Installed')" = $':code:\n:electron:\n:default:' ] \
  || fail "filtered batch map has incorrect results"
[ "$(/bin/bash "$output" ':code:')" = :default: ] \
  || fail "filter treated an inline icon assignment as an app pattern"
printf 'ok - filter preserves Code and emits a valid batch map\n'

printf 'sentinel\n' > "$output"
printf 'invalid upstream\n' > "$input"
if HOME="$TEST_ROOT/home" /usr/bin/python3 "$FILTER" --input "$input" --output "$output" >/dev/null 2>&1; then
  fail "filter accepted an upstream map without markers"
fi
[ "$(cat "$output")" = sentinel ] || fail "failed filter replaced its output"
printf 'ok - invalid upstream leaves the destination untouched\n'

cat > "$input" <<'MAP'
#!/usr/bin/env bash
### START-OF-ICON-MAP
function __icon_map() {
  case "$1" in
    "Code") icon_result=":wrong:" ;;
    "Code") icon_result=":code:" ;;
    *) icon_result=":default:" ;;
  esac
}
### END-OF-ICON-MAP
MAP
if HOME="$TEST_ROOT/home" /usr/bin/python3 "$FILTER" --input "$input" --output "$output" >/dev/null 2>&1; then
  fail "filter accepted a duplicate icon pattern"
fi
[ "$(cat "$output")" = sentinel ] || fail "duplicate pattern replaced the output"
printf 'ok - duplicate icon patterns are rejected\n'

install_home="$TEST_ROOT/install-home"
release_dir="$TEST_ROOT/release"
valid_font="$TEST_ROOT/sketchybar-app-font.ttf"
# Minimal CC0-1.0 subset of sketchybar-app-font containing the :code: ligature.
/usr/bin/base64 -D > "$valid_font" <<'FONT'
AAEAAAALAIAAAwAwR1NVQiCpJXMAAAHIAAAAXk9TLzJXOWhSAAACKAAAAGBjbWFwAIIBhgAAAXwA
AABKZ2x5ZgBU6UIAAAKIAAAAjGhlYWQwU4eaAAABRAAAADZoaGVhB9cFhwAAASAAAAAkaG10eAWD
//8AAADMAAAAFGxvY2EA0gDSAAAAvAAAABBtYXhwAZ8JFwAAAOAAAAAgbmFtZRY7NLgAAAMUAAAB
LHBvc3QADQAAAAABAAAAACAAAAAAAEYARgBGAEYARgBGAAAAAAWD//8AAAAAAAAAAAAAAAAAAQAA
AAcJCwCOAAAAAAACAAAACgAKAAAA/wAAAAAAAAADAAAAAAAAAAoAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAEAAAPoAAAAAAWD/yQAAATKAAEAAAAAAAAAAAAAAAAAAAADAAEAAAABAADAAbrrXw889QAL
A+gAAAAA5qMhNQAAAADmoyE1/yT/IgTKBSkAAAAIAAIAAAAAAAAAAAACAAAAAwAAABQAAwABAAAA
FAAEADYAAAAIAAgAAgAAADoAZQBv//8AAAA6AGMAb////8gAAP+VAAEAAAAGAAAAAAAFAAYAAwAA
AAEAAAAKACQAMgACREZMVAAObGF0bgAOAAQAAAAAAAAAAQAAAAFsaWdhAAgAAAABAAAAAQAEAAQA
AAABAAgAAQAaAAEACAABAAQAAQAGAAUABAAGAAMAAgABAAEAAgAAAAQFPAGQAAUAAAN/ArwAAACM
A38CvAAAAeAAMQECAAACAAUDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFBmRWQAwAA6AG8D6AAAAFoF
KQDeAAAAAQAAAAAAAAAAAAAAAAAhAAP//wAAA+kD6AAiACUAJgAAAScmBgcBJyYGDwEGFB8BBwYU
HwEeAT8BAR4BPwE+ATURNCYDLQERA8TNEicO/nasDB4LNw4OlJQODjcLHgysAYoOJxLOEBMT5/7V
ASsDfGMJBw7+mYIJAQozDCUMiIgMJQwzCgEJg/6YDgcJYwgeEgKgEh79nePj/joAAAAIAGYAAwAB
BAkAAQAmAKAAAwABBAkAAgAOAJIAAwABBAkAAwAmAKAAAwABBAkABAAmAKAAAwABBAkABQAWAHwA
AwABBAkABgAmAKAAAwABBAkACgBWACYAAwABBAkACwAmAAAAaAB0AHQAcAA6AC8ALwBmAG8AbgB0
AGUAbABsAG8ALgBjAG8AbQBHAGUAbgBlAHIAYQB0AGUAZAAgAGIAeQAgAHMAdgBnADIAdAB0AGYA
IABmAHIAbwBtACAARgBvAG4AdABlAGwAbABvACAAcAByAG8AagBlAGMAdAAuAFYAZQByAHMAaQBv
AG4AIAAxAC4AMABSAGUAZwB1AGwAYQByAHMAawBlAHQAYwBoAHkAYgBhAHIALQBhAHAAcAAtAGYA
bwBuAHQ=
FONT
mkdir -p "$install_home/.config/sketchybar/scripts" "$install_home/.config/sketchybar/plugins" "$release_dir"
cp "$FILTER" "$install_home/.config/sketchybar/scripts/filter_icon_map.py"
cp "$input" "$release_dir/icon_map.sh"
cp "$valid_font" "$release_dir/sketchybar-app-font.ttf"
printf 'old-map\n' > "$install_home/.config/sketchybar/plugins/icon_map.sh"

# Restore the valid fixture after the malformed-input check above.
cat > "$release_dir/icon_map.sh" <<'MAP'
#!/usr/bin/env bash
### START-OF-ICON-MAP
function __icon_map() {
  case "$1" in
    "Code" | "Code - Insiders") icon_result=":code:" ;;
    *) icon_result=":default:" ;;
  esac
}
### END-OF-ICON-MAP
MAP
HOME="$install_home" SKETCHYBAR_APP_FONT_RELEASE_URL="file://$release_dir" \
  "$CONFIG_ROOT/scripts/install-app-font" >/dev/null
[ "$($install_home/.config/sketchybar/plugins/icon_map.sh Code)" = :code: ] \
  || fail "installer did not publish the filtered map"
/usr/bin/cmp -s "$valid_font" \
  "$install_home/Library/Fonts/sketchybar-app-font.ttf" \
  || fail "installer did not publish the font"
printf 'ok - installer publishes validated artifacts\n'

map_hash="$(shasum -a 256 "$install_home/.config/sketchybar/plugins/icon_map.sh" | awk '{print $1}')"
font_hash="$(shasum -a 256 "$install_home/Library/Fonts/sketchybar-app-font.ttf" | awk '{print $1}')"

side_effect="$TEST_ROOT/upstream-side-effect"
cat > "$release_dir/icon_map.sh" <<MAP
#!/usr/bin/env bash
printf owned > "$side_effect"
### START-OF-ICON-MAP
function __icon_map() {
  case "\$1" in
    "Code") icon_result=":code:" ;;
    *) icon_result=":default:" ;;
  esac
}
### END-OF-ICON-MAP
MAP
HOME="$install_home" SKETCHYBAR_APP_FONT_RELEASE_URL="file://$release_dir" \
  "$CONFIG_ROOT/scripts/install-app-font" >/dev/null
[ ! -e "$side_effect" ] || fail "installer executed upstream shell content"
! grep -q 'upstream-side-effect' "$install_home/.config/sketchybar/plugins/icon_map.sh" \
  || fail "installer preserved upstream shell content"
map_hash="$(shasum -a 256 "$install_home/.config/sketchybar/plugins/icon_map.sh" | awk '{print $1}')"
font_hash="$(shasum -a 256 "$install_home/Library/Fonts/sketchybar-app-font.ttf" | awk '{print $1}')"
printf 'ok - installer strips upstream shell content without executing it\n'

printf 'invalid upstream\n' > "$release_dir/icon_map.sh"
cp "$valid_font" "$release_dir/sketchybar-app-font.ttf"
if HOME="$install_home" SKETCHYBAR_APP_FONT_RELEASE_URL="file://$release_dir" \
  "$CONFIG_ROOT/scripts/install-app-font" >/dev/null 2>&1; then
  fail "installer accepted an invalid upstream map"
fi
[ "$(shasum -a 256 "$install_home/.config/sketchybar/plugins/icon_map.sh" | awk '{print $1}')" = "$map_hash" ] \
  || fail "failed install replaced the live map"
[ "$(shasum -a 256 "$install_home/Library/Fonts/sketchybar-app-font.ttf" | awk '{print $1}')" = "$font_hash" ] \
  || fail "failed install replaced the live font"
printf 'ok - failed install preserves live artifacts\n'

cp /System/Library/Fonts/SFNS.ttf "$release_dir/sketchybar-app-font.ttf"
cat > "$release_dir/icon_map.sh" <<'MAP'
#!/usr/bin/env bash
### START-OF-ICON-MAP
function __icon_map() {
  case "$1" in
    "Code") icon_result=":code:" ;;
    *) icon_result=":default:" ;;
  esac
}
### END-OF-ICON-MAP
MAP
if HOME="$install_home" SKETCHYBAR_APP_FONT_RELEASE_URL="file://$release_dir" \
  "$CONFIG_ROOT/scripts/install-app-font" >/dev/null 2>&1; then
  fail "installer accepted an unrelated SFNT font"
fi
[ "$(shasum -a 256 "$install_home/.config/sketchybar/plugins/icon_map.sh" | awk '{print $1}')" = "$map_hash" ] \
  || fail "font identity failure replaced the live map"
[ "$(shasum -a 256 "$install_home/Library/Fonts/sketchybar-app-font.ttf" | awk '{print $1}')" = "$font_hash" ] \
  || fail "font identity failure replaced the live font"
printf 'ok - unrelated SFNT font preserves live artifacts\n'

cp "$valid_font" "$release_dir/sketchybar-app-font.ttf"
cat > "$release_dir/icon_map.sh" <<'MAP'
#!/usr/bin/env bash
### START-OF-ICON-MAP
function __icon_map() {
  case "$1" in
    "Code") icon_result=":unexpected:" ;;
    *) icon_result=":default:" ;;
  esac
}
### END-OF-ICON-MAP
MAP
if HOME="$install_home" SKETCHYBAR_APP_FONT_RELEASE_URL="file://$release_dir" \
  "$CONFIG_ROOT/scripts/install-app-font" >/dev/null 2>&1; then
  fail "installer accepted a map with an incompatible lookup contract"
fi
[ "$(shasum -a 256 "$install_home/.config/sketchybar/plugins/icon_map.sh" | awk '{print $1}')" = "$map_hash" ] \
  || fail "contract failure replaced the live map"
[ "$(shasum -a 256 "$install_home/Library/Fonts/sketchybar-app-font.ttf" | awk '{print $1}')" = "$font_hash" ] \
  || fail "contract failure replaced the live font"
printf 'ok - incompatible map contract preserves live artifacts\n'
