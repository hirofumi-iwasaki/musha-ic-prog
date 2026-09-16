#!/bin/sh
# Create a pinned MiniPro source tree plus the local SRAM overlay, without .git.
set -eu

expected_commit=cae74c0607077d6260b24995f5e4c0d0b66a6a2e
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
source_dir=${MINIPRO_SOURCE:-/private/tmp/musha-minipro-license-review}
tooling_dir=$repo_dir/.tooling
output_dir=${1:-"$tooling_dir/minipro-sram"}

if [ ! -d "$source_dir/.git" ]; then
    echo "MiniPro checkout is missing: $source_dir" >&2
    echo "Set MINIPRO_SOURCE to an upstream checkout at $expected_commit." >&2
    exit 1
fi

actual_commit=$(git -C "$source_dir" rev-parse "$expected_commit^{commit}")
if [ "$actual_commit" != "$expected_commit" ]; then
    echo "Required upstream commit is unavailable in $source_dir: $expected_commit" >&2
    exit 1
fi

if [ -L "$tooling_dir" ]; then
    echo "Refusing symlinked tooling directory: $tooling_dir" >&2
    exit 1
fi
mkdir -p "$tooling_dir"
if [ ! -d "$tooling_dir" ]; then
    echo "Tooling path is not a directory: $tooling_dir" >&2
    exit 1
fi

case "$output_dir" in
    "$tooling_dir"/*) output_name=${output_dir#"$tooling_dir"/} ;;
    *)
        echo "Output must be a new direct child of $tooling_dir" >&2
        exit 1
        ;;
esac
case "$output_name" in
    ''|.|..|*/*)
        echo "Output must be a new direct child of $tooling_dir" >&2
        exit 1
        ;;
esac

if [ -e "$output_dir" ] || [ -L "$output_dir" ]; then
    echo "Output already exists; choose a new path or remove it yourself: $output_dir" >&2
    exit 1
fi

staging_dir=$(mktemp -d "$tooling_dir/.minipro-sram-staging.XXXXXX")
trap 'rm -rf "$staging_dir"' EXIT HUP INT TERM
git -C "$source_dir" archive "$expected_commit" | tar -x -C "$staging_dir"

cp "$repo_dir/third_party/minipro/sram/sram_test.c" "$staging_dir/src/sram_test.c"
cp "$repo_dir/third_party/minipro/sram/sram_test.h" "$staging_dir/src/sram_test.h"

if ! grep -q 'src/sram_test.o' "$staging_dir/Makefile"; then
    makefile_tmp="$staging_dir/Makefile.tmp"
    awk '
        /^COMMON_OBJECTS=/ {
            print
            print "\t\tsrc/sram_test.o \\"
            next
        }
        { print }
    ' "$staging_dir/Makefile" > "$makefile_tmp"
    mv "$makefile_tmp" "$staging_dir/Makefile"
fi

test ! -e "$staging_dir/.git"
grep -q 'src/sram_test.o' "$staging_dir/Makefile"
test -f "$staging_dir/src/sram_test.c"
test -f "$staging_dir/LICENSE"
mv "$staging_dir" "$output_dir"
trap - EXIT HUP INT TERM
printf '%s\n' "Materialized MiniPro $expected_commit at $output_dir"
printf '%s\n' "No TL866CS SRAM adapter is enabled by this overlay."
