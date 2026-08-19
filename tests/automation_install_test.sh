#!/bin/bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/automation-install-test.XXXXXX")
trap 'rm -rf "$TEST_HOME"' EXIT

cd "$REPO_ROOT"
stow --target "$TEST_HOME" automation

HOME="$TEST_HOME" "$TEST_HOME/.local/libexec/install-chrome-icon-agent" >/dev/null

destination="$TEST_HOME/Library/LaunchAgents/com.ghot.chrome-custom-icon.plist"
expected="$TEST_HOME/.local/libexec/chrome-icon"
actual=$(/usr/bin/plutil -extract ProgramArguments.0 raw "$destination")

[[ -f "$destination" && ! -L "$destination" ]]
[[ "$actual" == "$expected" ]]
/usr/bin/plutil -lint "$destination" >/dev/null

HOME="$TEST_HOME" "$TEST_HOME/.local/libexec/install-chrome-icon-agent" >/dev/null
[[ "$(/usr/bin/plutil -extract ProgramArguments.0 raw "$destination")" == "$expected" ]]

echo "automation_install_test: ok"
