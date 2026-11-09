#!/usr/bin/env bash
# Host (macOS) unit tests for the Gamuroid additions that have no emulator dependency.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="${1:-$ROOT/work/melonds-ds}"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
xcrun clang++ -std=c++17 -Wall -Wextra -Werror -fsanitize=address,undefined \
    -I "$WRAPPER/src/libretro" \
    "$ROOT/tests/screen_layout_value_test.cpp" \
    "$WRAPPER/src/libretro/gamuroid/screen_layout_value.cpp" \
    -o "$OUT/screen_layout_value_test"
"$OUT/screen_layout_value_test"
xcrun clang++ -std=c++17 -Wall -Wextra -Werror -fsanitize=address,undefined \
    -I "$WRAPPER/src/libretro" \
    "$ROOT/tests/net_state_test.cpp" \
    "$WRAPPER/src/libretro/gamuroid/net_state.cpp" \
    -o "$OUT/net_state_test"
"$OUT/net_state_test"
