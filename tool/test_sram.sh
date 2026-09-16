#!/bin/sh
# Compile and run the local, hardware-independent SRAM engine mock suite.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
compiler=${CC:-clang}
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/musha-sram-test.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
output=$temp_dir/test_sram_test

"$compiler" -std=c11 -Wall -Wextra -Werror -pedantic \
    "$repo_dir/third_party/minipro/sram/sram_test.c" \
    "$repo_dir/tests/test_sram_test.c" \
    -o "$output"
"$output"
