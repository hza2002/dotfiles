#!/bin/bash
set -eu

TEST_DIR="$(cd "$(dirname "$0")" && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-temperature-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

clang -std=c99 -Wall -Wextra -Werror \
  -framework IOKit \
  "$TEST_DIR/temperature_test.c" \
  -o "$TEST_ROOT/temperature_test"

"$TEST_ROOT/temperature_test"
