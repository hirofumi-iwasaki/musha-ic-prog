#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds only project-local arm64 native payloads. It never uses Homebrew's
# libusb at runtime and does not contact or operate a USB device.
set -euo pipefail

repo_dir=${0:A:h:h}
libusb_version='1.0.29'
libusb_sha256='5977fc950f8d1395ccea9bd48c06b3f808fd3c2c961b44b0c2e6e29fc3a70a85'
archive="$repo_dir/.tooling/native-src/libusb-$libusb_version.tar.bz2"
prefix="$repo_dir/.tooling/native-prefix"
tools_dir="$repo_dir/.tooling/native-tools"
min_os='15.0'
libusb_work_dir=''
minipro_dir=''

cleanup() {
  if [[ -n "$libusb_work_dir" && -d "$libusb_work_dir" ]]; then
    rm -rf "$libusb_work_dir"
  fi
  if [[ -n "$minipro_dir" && -d "$minipro_dir" ]]; then
    rm -rf "$minipro_dir"
  fi
}
trap cleanup EXIT

if [[ "$(uname -m)" != 'arm64' ]]; then
  print -u2 'This initial native payload is arm64-only and must be built on Apple Silicon.'
  exit 1
fi
if [[ ! -f "$archive" ]]; then
  zsh "$repo_dir/tool/fetch_native_sources.sh"
fi
actual_sha256=$(shasum -a 256 "$archive" | awk '{print $1}')
if [[ "$actual_sha256" != "$libusb_sha256" ]]; then
  print -u2 'Pinned libusb archive hash mismatch.'
  exit 1
fi
libusb_work_dir=$(mktemp -d "$repo_dir/.tooling/.libusb-native.XXXXXX")
source_dir="$libusb_work_dir/source"
build_dir="$libusb_work_dir/build"
mkdir -p "$source_dir" "$build_dir" "$prefix" "$tools_dir"
tar -xjf "$archive" --strip-components=1 -C "$source_dir"

zsh "$repo_dir/tool/fetch_native_sources.sh"
minipro_dir=$(mktemp -d "$repo_dir/.tooling/.minipro-native.XXXXXX")
rmdir "$minipro_dir"
sh "$repo_dir/tool/materialize_minipro_sram.sh" "$minipro_dir"

(cd "$build_dir" && env ac_cv_func_pipe2=no MACOSX_DEPLOYMENT_TARGET="$min_os" \
  CFLAGS="-O2 -arch arm64 -mmacosx-version-min=$min_os" \
  LDFLAGS="-arch arm64 -mmacosx-version-min=$min_os" \
  "$source_dir/configure" --prefix="$prefix" --disable-static --enable-shared)
make -C "$build_dir" -j"$(sysctl -n hw.ncpu)"
make -C "$build_dir" install

ln -sf "$repo_dir/tool/pkg-config-native.sh" "$tools_dir/pkg-config"
export PATH="$tools_dir:$PATH"
export MUSHA_NATIVE_PREFIX="$prefix"
make -C "$minipro_dir" clean
make -C "$minipro_dir" \
  CC=clang \
  CFLAGS="-O2 -arch arm64 -mmacosx-version-min=$min_os" \
  LDFLAGS="-arch arm64 -mmacosx-version-min=$min_os -Wl,-rpath,@loader_path/../lib"

mkdir -p "$prefix/bin"
cp "$minipro_dir/minipro" "$prefix/bin/minipro"
install_name_tool -change "$prefix/lib/libusb-1.0.0.dylib" \
  '@rpath/libusb-1.0.0.dylib' "$prefix/bin/minipro"
install_name_tool -add_rpath '@loader_path/../lib' "$prefix/bin/minipro" 2>/dev/null || true

clang -O2 -arch arm64 -mmacosx-version-min="$min_os" \
  -I"$prefix/include/libusb-1.0" "$repo_dir/native/tl866_probe.c" \
  -L"$prefix/lib" -lusb-1.0 \
  -Wl,-rpath,@loader_path/../lib -o "$prefix/bin/tl866_probe"
install_name_tool -change "$prefix/lib/libusb-1.0.0.dylib" \
  '@rpath/libusb-1.0.0.dylib' "$prefix/bin/tl866_probe"

for artifact in "$prefix/bin/minipro" "$prefix/bin/tl866_probe" \
    "$prefix/lib/libusb-1.0.0.dylib"; do
  if [[ "$(lipo -archs "$artifact")" != 'arm64' ]]; then
    print -u2 "Native artifact is not arm64-only: $artifact"
    exit 1
  fi
done
mkdir -p "$prefix/resources/minipro"
for resource in infoic.xml logicic.xml LICENSE README.md; do
  cp "$minipro_dir/$resource" "$prefix/resources/minipro/$resource"
done
cmp -s "$prefix/resources/minipro/infoic.xml" "$repo_dir/assets/minipro/infoic.xml"
cmp -s "$prefix/resources/minipro/logicic.xml" "$repo_dir/assets/minipro/logicic.xml"

cat > "$prefix/BUILD-MANIFEST.txt" <<EOF
target_architecture=arm64
minimum_macos=$min_os
libusb_version=$libusb_version
libusb_sha256=$libusb_sha256
minipro_commit=cae74c0607077d6260b24995f5e4c0d0b66a6a2e
minipro_overlay=sram_test.c,sram_test.h
minipro_sram_test_c_sha256=$(shasum -a 256 "$repo_dir/third_party/minipro/sram/sram_test.c" | awk '{print $1}')
minipro_sram_test_h_sha256=$(shasum -a 256 "$repo_dir/third_party/minipro/sram/sram_test.h" | awk '{print $1}')
tl866_probe_c_sha256=$(shasum -a 256 "$repo_dir/native/tl866_probe.c" | awk '{print $1}')
infoic_xml_sha256=$(shasum -a 256 "$prefix/resources/minipro/infoic.xml" | awk '{print $1}')
logicic_xml_sha256=$(shasum -a 256 "$prefix/resources/minipro/logicic.xml" | awk '{print $1}')
xcode_build=$(xcodebuild -version | tr '\n' ' ')
EOF

file "$prefix/bin/minipro" "$prefix/bin/tl866_probe" "$prefix/lib/libusb-1.0.0.dylib"
otool -L "$prefix/bin/minipro" "$prefix/bin/tl866_probe"
print "Built native arm64 payload at $prefix"
