#!/bin/bash
set -eu

CONFIG_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-network-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

cat > "$TEST_ROOT/network_filter_test.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>

#include "network.h"

static void expect_skipped(const char *name) {
  if (!network_skip_interface(name)) {
    fprintf(stderr, "not ok - expected %s to be skipped\n", name);
    exit(1);
  }
}

static void expect_included(const char *name) {
  if (network_skip_interface(name)) {
    fprintf(stderr, "not ok - expected %s to be included\n", name);
    exit(1);
  }
}

int main(void) {
  expect_skipped("utun0");
  expect_skipped("utun12");
  puts("ok - tunnel interfaces are excluded");

  expect_included("en0");
  expect_included("en7");
  puts("ok - physical network interfaces remain included");

  expect_skipped("bridge0");
  puts("ok - existing virtual interface filtering is preserved");
  puts("1..3");
  return 0;
}
EOF

/usr/bin/clang -std=c99 -Wall -Wextra -Werror \
  -I "$CONFIG_ROOT/helper" \
  "$TEST_ROOT/network_filter_test.c" \
  -o "$TEST_ROOT/network_filter_test"
"$TEST_ROOT/network_filter_test"
