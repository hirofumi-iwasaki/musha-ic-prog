#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Compile and run the actual materialized MiniPro guard without opening USB.
set -euo pipefail
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
[[ ! -L "$project_dir/.tooling" ]] || { echo 'Refusing symlinked tooling directory' >&2; exit 1; }
mkdir -p "$project_dir/.tooling"
output=$(mktemp -d "$project_dir/.tooling/minipro-guard-fixture.XXXXXX")
rmdir "$output"
owns_output=0
cleanup() {
  [[ $owns_output == 1 && -d $output ]] && rm -rf "$output"
}
trap cleanup EXIT HUP INT TERM
sh "$project_dir/tool/materialize_minipro_sram.sh" "$output"
owns_output=1
cp "$project_dir/tests/test_programmer_guard.c" "$output/src/test_programmer_guard.c"
cat > "$output/src/version.h" <<'EOF'
#define VERSION "fixture"
#define GIT_DATE "fixture"
#define GIT_HASH "fixture"
#define GIT_BRANCH "fixture"
#define SHARE_INSTDIR "fixture"
EOF
cc=${CC:-cc}
case "$(uname -s)" in
  Darwin) dead_strip=(-Wl,-dead_strip) ;;
  *) dead_strip=(-Wl,--gc-sections) ;;
esac
"$cc" -std=c11 -O0 -ffunction-sections -fdata-sections -I"$output/src" \
  "$output/src/test_programmer_guard.c" "${dead_strip[@]}" -o "$output/test_programmer_guard"
"$output/test_programmer_guard"
printf '%s\n' 'MiniPro same-handle guard fixture passed (no USB opened).'
