#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Build and package a complete Ubuntu 22.04-baseline Linux Flutter bundle.
set -euo pipefail
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
case "$(uname -m)" in x86_64) host_arch=x64;; aarch64|arm64) host_arch=arm64;; *) echo 'Unsupported Linux host.' >&2; exit 1;; esac
architecture=${1:-$host_arch}; [[ $architecture == "$host_arch" ]] || { echo "A native Linux $architecture host is required." >&2; exit 1; }
flutter_bin=${FLUTTER_BIN:-}; if [[ -z $flutter_bin ]]; then
  if [[ -x "$project_dir/.tooling/flutter/bin/flutter" ]]; then flutter_bin="$project_dir/.tooling/flutter/bin/flutter";
  elif [[ -x "$(dirname "$project_dir")/musha-bin-editor/.tooling/flutter/bin/flutter" ]]; then flutter_bin="$(dirname "$project_dir")/musha-bin-editor/.tooling/flutter/bin/flutter";
  else echo 'Set FLUTTER_BIN or provide the pinned sibling Flutter SDK.' >&2; exit 1; fi
fi
[[ -x $flutter_bin ]] || { echo 'Flutter 3.47.4 is required.' >&2; exit 1; }
cd "$project_dir"
"$project_dir/tool/build_native_linux.sh" "$architecture"
"$flutter_bin" pub get; "$flutter_bin" build linux --release
bundle="$project_dir/build/linux/$architecture/release/bundle"; [[ -x "$bundle/mushagaeshi_ic_programmer" ]] || { echo 'Missing Flutter bundle.' >&2; exit 1; }
prefix="$project_dir/.tooling/native-prefix-linux-$architecture"
mkdir -p "$bundle/native" "$bundle/resources/minipro"
install -m 0755 "$prefix/native/minipro" "$bundle/native/minipro"; install -m 0755 "$prefix/native/tl866_probe" "$bundle/native/tl866_probe"
cp -a "$prefix/lib/libusb-1.0.so"* "$bundle/lib/"; cp -a "$prefix/lib/libz.so"* "$bundle/lib/"; cp -a "$prefix/resources/minipro/." "$bundle/resources/minipro/"
install -m 0644 "$prefix/BUILD-MANIFEST.txt" "$bundle/resources/minipro/BUILD-MANIFEST.txt"
install -m 0644 "$project_dir/third_party/libusb/LICENSE" "$bundle/resources/minipro/libusb-LGPL-2.1-or-later.txt"
install -m 0644 "$project_dir/third_party/minipro/UPSTREAM.toml" "$bundle/resources/minipro/minipro-UPSTREAM.toml"
install -m 0644 "$project_dir/third_party/libusb/UPSTREAM.toml" "$bundle/resources/minipro/libusb-UPSTREAM.toml"
install -m 0644 "$project_dir/third_party/zlib-UPSTREAM.toml" "$bundle/resources/minipro/zlib-UPSTREAM.toml"
install -m 0644 "$project_dir/third_party/ZLIB_LICENSE.txt" "$bundle/resources/minipro/zlib-Zlib.txt"
install -m 0644 "$project_dir/linux/udev/60-mushagaeshi-tl866.rules" "$bundle/resources/minipro/60-mushagaeshi-tl866.rules"
install -m 0644 "$project_dir/linux/udev/README.md" "$bundle/resources/minipro/LINUX_UDEV_SETUP.md"
machine='Advanced Micro Devices X86-64'; [[ $architecture == arm64 ]] && machine='AArch64'
while IFS= read -r -d '' artifact; do readelf -h "$artifact" | grep -Fq "Machine:                           $machine" || { echo "Unexpected ELF architecture: $artifact" >&2; exit 1; }; ldd "$artifact" | grep -q 'not found' && { echo "Unresolved library: $artifact" >&2; exit 1; } || true; done < <(find "$bundle" -type f \( -perm -0100 -o -name '*.so' -o -name '*.so.*' \) -print0)
for helper in "$bundle/native/minipro" "$bundle/native/tl866_probe"; do readelf -d "$helper" | grep -Eq 'RUNPATH.*\$ORIGIN/../lib' || { echo "Incorrect helper RPATH: $helper" >&2; exit 1; }; done
dist="$project_dir/dist"; mkdir -p "$dist"; stage=$(mktemp -d "$dist/.linux-package.XXXXXX"); trap 'rm -rf "$stage"' EXIT HUP INT TERM
distribution="$stage/mushagaeshi_ic_programmer"; cp -a "$bundle" "$distribution"
"$flutter_bin" pub run tool/ci/package_sources.dart "$distribution"
native_sources="$distribution/SOURCE/third_party/native-sources"; mkdir -p "$native_sources"
tar -xjf "$project_dir/.tooling/native-src/libusb-1.0.29.tar.bz2" -C "$native_sources"; tar -xzf "$project_dir/.tooling/native-src/zlib-1.3.2.tar.gz" -C "$native_sources"
source_minipro="$native_sources/minipro-cae74c0607077d6260b24995f5e4c0d0b66a6a2e"; mkdir "$source_minipro"
tar -xzf "$project_dir/.tooling/native-src/minipro-cae74c0607077d6260b24995f5e4c0d0b66a6a2e.tar.gz" --strip-components=1 -C "$source_minipro"
cp "$project_dir/third_party/minipro/sram/sram_test.c" "$source_minipro/src/sram_test.c"; cp "$project_dir/third_party/minipro/sram/sram_test.h" "$source_minipro/src/sram_test.h"
if ! grep -q 'src/sram_test.o' "$source_minipro/Makefile"; then awk '/^COMMON_OBJECTS=/ {print; print "\t\tsrc/sram_test.o \\"; next} {print}' "$source_minipro/Makefile" > "$source_minipro/Makefile.new"; mv "$source_minipro/Makefile.new" "$source_minipro/Makefile"; fi
"$flutter_bin" pub run tool/ci/write_distribution_metadata.dart "$distribution" "linux-$architecture" "$flutter_bin"
"$flutter_bin" pub run tool/ci/write_checksums.dart "$distribution"
tar -C "$stage" -czf "$dist/musha-ic-prog-linux-$architecture.tar.gz" mushagaeshi_ic_programmer
printf 'Linux package ready: %s\n' "$dist/musha-ic-prog-linux-$architecture.tar.gz"
