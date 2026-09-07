#!/bin/bash
set -euo pipefail

label=com.ghot.display-control
source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts_dir="$HOME/.config/raycast/scripts"
binary="$HOME/.local/libexec/display-control"
agent="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

check_links() {
  local name destination
  for name in toggle-internal-display.sh internal-display.png; do
    destination="$scripts_dir/$name"
    if [[ -e "$destination" || -L "$destination" ]]; then
      if [[ ! -L "$destination" ]] || [[ "$(readlink "$destination")" != "$source_dir/$name" ]]; then
        echo "Refusing to replace unrelated file: $destination" >&2
        return 1
      fi
    fi
  done
}

link_command() {
  check_links
  mkdir -p "$scripts_dir"
  local name
  for name in toggle-internal-display.sh internal-display.png; do
    [[ -L "$scripts_dir/$name" ]] || ln -s "$source_dir/$name" "$scripts_dir/$name"
  done
}

unlink_command() {
  local name destination
  for name in toggle-internal-display.sh internal-display.png; do
    destination="$scripts_dir/$name"
    if [[ -L "$destination" ]] && [[ "$(readlink "$destination")" == "$source_dir/$name" ]]; then
      rm "$destination"
    fi
  done
}

build() {
  local destination=$1
  /usr/bin/swiftc -parse-as-library "$source_dir/main.swift" -o "$destination" \
    -framework AppKit -framework CoreGraphics -framework IOKit
}

case "${1:-}" in
  link)
    link_command
    echo "Linked Raycast command; service unchanged."
    ;;
  check|check-live)
    temporary=$(mktemp -d "${TMPDIR:-/tmp}/display-control-check.XXXXXX")
    trap 'rm -rf "$temporary"' EXIT
    build "$temporary/display-control"
    /usr/bin/swiftc -parse-as-library -D TESTING "$source_dir/main.swift" "$source_dir/tests.swift" \
      -o "$temporary/tests" -framework AppKit -framework CoreGraphics -framework IOKit
    "$temporary/tests"
    if [[ "$1" == check-live ]]; then
      "$temporary/tests" --live
    fi
    ;;
  install)
    check_links
    mkdir -p "$(dirname "$binary")" "$(dirname "$agent")"
    temporary=$(mktemp -d "${TMPDIR:-/tmp}/display-control-install.XXXXXX")
    trap 'rm -rf "$temporary"' EXIT
    build "$temporary/display-control"
    "$temporary/display-control" probe
    if launchctl print "$domain/$label" >/dev/null 2>&1; then
      "$binary" pause
      launchctl bootout "$domain/$label"
    fi
    install -m 0755 "$temporary/display-control" "$binary"
    /usr/bin/plutil -create xml1 "$temporary/agent.plist"
    /usr/bin/plutil -insert Label -string "$label" "$temporary/agent.plist"
    /usr/bin/plutil -insert ProgramArguments -json '[]' "$temporary/agent.plist"
    /usr/bin/plutil -insert ProgramArguments.0 -string "$binary" "$temporary/agent.plist"
    /usr/bin/plutil -insert ProgramArguments.1 -string daemon "$temporary/agent.plist"
    /usr/bin/plutil -insert RunAtLoad -bool YES "$temporary/agent.plist"
    /usr/bin/plutil -insert KeepAlive -json '{"SuccessfulExit":false}' "$temporary/agent.plist"
    /usr/bin/plutil -insert ThrottleInterval -integer 10 "$temporary/agent.plist"
    /usr/bin/plutil -insert ProcessType -string Interactive "$temporary/agent.plist"
    /usr/bin/plutil -insert ExitTimeOut -integer 30 "$temporary/agent.plist"
    /usr/bin/plutil -insert LimitLoadToSessionType -string Aqua "$temporary/agent.plist"
    /usr/bin/plutil -insert StandardErrorPath -string "$HOME/Library/Logs/display-control.log" "$temporary/agent.plist"
    /usr/bin/plutil -lint "$temporary/agent.plist"
    install -m 0644 "$temporary/agent.plist" "$agent"
    link_command
    launchctl bootstrap "$domain" "$agent"
    echo "Installed display-control. First installation starts paused."
    ;;
  start) launchctl kickstart "$domain/$label" ;;
  uninstall)
    if launchctl print "$domain/$label" >/dev/null 2>&1; then
      "$binary" pause
      "$binary" check-restored
      launchctl bootout "$domain/$label"
    fi
    if [[ -x "$binary" ]]; then
      "$binary" check-restored
    elif [[ -e "$agent" ]]; then
      echo "Controller binary missing; reinstall before uninstalling to verify panel recovery." >&2
      exit 1
    fi
    rm -f "$agent" "$binary"
    unlink_command
    echo "Removed agent, binary and owned Raycast links; retained mode state and logs."
    ;;
  *) echo "Usage: $0 check|check-live|link|install|start|uninstall" >&2; exit 2 ;;
esac
