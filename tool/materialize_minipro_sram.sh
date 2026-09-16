#!/bin/sh
# Create a pinned MiniPro source tree plus the local SRAM overlay, without .git.
set -eu

expected_commit=cae74c0607077d6260b24995f5e4c0d0b66a6a2e
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
tooling_dir=$repo_dir/.tooling
output_dir=${1:-"$tooling_dir/minipro-sram"}
source_archive="$tooling_dir/native-src/minipro-$expected_commit.tar.gz"
source_archive_sha256='6363acb0b69f6038ff7a64a751bd2b4fa671debde487c83fd4c5c876c95175af'

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
if [ -n "${MINIPRO_SOURCE:-}" ]; then
    if [ ! -d "$MINIPRO_SOURCE/.git" ]; then
        echo "MINIPRO_SOURCE is not an upstream Git checkout: $MINIPRO_SOURCE" >&2
        exit 1
    fi
    actual_commit=$(git -C "$MINIPRO_SOURCE" rev-parse "$expected_commit^{commit}")
    if [ "$actual_commit" != "$expected_commit" ]; then
        echo "Required upstream commit is unavailable: $expected_commit" >&2
        exit 1
    fi
    git -C "$MINIPRO_SOURCE" archive "$expected_commit" | tar -x -C "$staging_dir"
else
    if [ ! -f "$source_archive" ]; then
        echo "Missing $source_archive. Run tool/fetch_native_sources.sh first." >&2
        exit 1
    fi
    actual_sha256=$(shasum -a 256 "$source_archive" | awk '{print $1}')
    if [ "$actual_sha256" != "$source_archive_sha256" ]; then
        echo "Pinned minipro source archive hash mismatch." >&2
        exit 1
    fi
    tar -xzf "$source_archive" --strip-components=1 -C "$staging_dir"
fi

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
