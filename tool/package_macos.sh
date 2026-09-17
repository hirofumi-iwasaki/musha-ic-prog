#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Create the public Arm64 macOS distribution, including corresponding source.
set -euo pipefail

project_dir=${0:A:h:h}
output_dir=${1:-"$project_dir/dist"}
app_name='Mushagaeshi IC Programmer.app'
archive_name='musha-ic-prog-macos-arm64.zip'
stage_dir=''
materialized_minipro=''

cleanup() {
  [[ -n "$stage_dir" && -d "$stage_dir" ]] && rm -rf "$stage_dir"
  [[ -n "$materialized_minipro" && -d "$materialized_minipro" ]] && rm -rf "$materialized_minipro"
}
trap cleanup EXIT HUP INT TERM

cd "$project_dir"
zsh "$project_dir/tool/build_macos.sh" "$output_dir"
app="$output_dir/$app_name"
[[ -d "$app" ]] || { print -u2 'Missing macOS application bundle.'; exit 1; }
[[ "$(lipo -archs "$app/Contents/MacOS/Mushagaeshi IC Programmer")" == *arm64* ]] || {
  print -u2 'The macOS application does not contain an Arm64 slice.'
  exit 1
}

stage_dir=$(mktemp -d "$output_dir/.macos-package.XXXXXX")
distribution_dir="$stage_dir/Mushagaeshi IC Programmer"
source_dir="$distribution_dir/SOURCE"
mkdir -p "$distribution_dir" "$source_dir"
ditto "$app" "$distribution_dir/$app_name"

flutter_bin=${FLUTTER_BIN:-flutter}
"$flutter_bin" pub run tool/ci/package_sources.dart "$distribution_dir"

native_sources="$source_dir/third_party/native-sources"
mkdir -p "$native_sources"
libusb_archive="$project_dir/.tooling/native-src/libusb-1.0.29.tar.bz2"
[[ -f "$libusb_archive" ]] || { print -u2 'Missing verified libusb source archive.'; exit 1; }
tar -xjf "$libusb_archive" -C "$native_sources"

materialized_minipro="$project_dir/.tooling/release-minipro-source.$RANDOM"
sh "$project_dir/tool/materialize_minipro_sram.sh" "$materialized_minipro"
ditto "$materialized_minipro" "$native_sources/minipro-cae74c0607077d6260b24995f5e4c0d0b66a6a2e"

flutter_bin=${FLUTTER_BIN:-flutter}
"$flutter_bin" pub run tool/ci/write_distribution_metadata.dart "$distribution_dir" macos-arm64 "$flutter_bin"
"$flutter_bin" pub run tool/ci/write_checksums.dart "$distribution_dir"
archive_stage="$stage_dir/$archive_name"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$distribution_dir" "$archive_stage"
mv "$archive_stage" "$output_dir/$archive_name"
print "macOS release package ready: $output_dir/$archive_name"
