#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
flutter_bin=${FLUTTER_BIN:-flutter}
output_dir=${1:-"$project_dir/dist"}
app_name='Mushagaeshi IC Programmer.app'
release_app="$project_dir/build/macos/Build/Products/Release/$app_name"
target_app="$output_dir/$app_name"
stage_dir=''
native_prefix="$project_dir/.tooling/native-prefix"
helper_entitlements="$project_dir/macos/Runner/MiniproHelper.entitlements"
app_entitlements="$project_dir/macos/Runner/Release.entitlements"
sign_identity=${CODE_SIGN_IDENTITY:--}

cleanup() {
  if [[ -n "$stage_dir" && -d "$stage_dir" ]]; then
    rm -rf "$stage_dir"
  fi
}
trap cleanup EXIT

sign_code() {
  local target="$1"
  shift
  if [[ "$sign_identity" == '-' ]]; then
    codesign --force --sign - --timestamp=none "$@" "$target"
  else
    codesign --force --sign "$sign_identity" --options runtime --timestamp "$@" "$target"
  fi
}

bundle_native_payload() {
  local app_path="$1"
  local macos_dir="$app_path/Contents/MacOS"
  local frameworks_dir="$app_path/Contents/Frameworks"
  local resources_dir="$app_path/Contents/Resources/minipro"
  local minipro="$native_prefix/bin/minipro"
  local probe="$native_prefix/bin/tl866_probe"
  local libusb="$native_prefix/lib/libusb-1.0.0.dylib"
  local minipro_resources="$native_prefix/resources/minipro"

  for payload in "$minipro" "$probe" "$libusb" \
      "$minipro_resources/infoic.xml" "$minipro_resources/logicic.xml" \
      "$minipro_resources/LICENSE" "$minipro_resources/README.md" \
      "$project_dir/third_party/libusb/LICENSE" \
      "$project_dir/third_party/minipro/UPSTREAM.toml" \
      "$project_dir/third_party/libusb/UPSTREAM.toml" \
      "$project_dir/third_party/NATIVE_REBUILDING.md"; do
    if [[ ! -f "$payload" ]]; then
      print -u2 "Missing native payload: $payload"
      exit 1
    fi
  done
  mkdir -p "$frameworks_dir" "$resources_dir"
  rm -f "$macos_dir/minipro" "$macos_dir/tl866_probe" \
    "$frameworks_dir/libusb-1.0.0.dylib"
  rm -rf "$resources_dir"
  mkdir -p "$resources_dir"
  ditto "$minipro" "$macos_dir/minipro"
  ditto "$probe" "$macos_dir/tl866_probe"
  ditto "$libusb" "$frameworks_dir/libusb-1.0.0.dylib"
  ditto "$minipro_resources/infoic.xml" "$resources_dir/infoic.xml"
  ditto "$minipro_resources/logicic.xml" "$resources_dir/logicic.xml"
  ditto "$minipro_resources/LICENSE" "$resources_dir/minipro-GPL-3.0-or-later.txt"
  ditto "$minipro_resources/README.md" "$resources_dir/minipro-UPSTREAM_README.md"
  ditto "$project_dir/third_party/libusb/LICENSE" "$resources_dir/libusb-LGPL-2.1-or-later.txt"
  ditto "$project_dir/third_party/minipro/UPSTREAM.toml" "$resources_dir/minipro-UPSTREAM.toml"
  ditto "$project_dir/third_party/libusb/UPSTREAM.toml" "$resources_dir/libusb-UPSTREAM.toml"
  ditto "$project_dir/third_party/NATIVE_REBUILDING.md" "$resources_dir/NATIVE_REBUILDING.md"
  ditto "$native_prefix/BUILD-MANIFEST.txt" "$resources_dir/BUILD-MANIFEST.txt"

  install_name_tool -id '@rpath/libusb-1.0.0.dylib' \
    "$frameworks_dir/libusb-1.0.0.dylib"
  install_name_tool -delete_rpath '@loader_path/../lib' \
    "$macos_dir/minipro" 2>/dev/null || true
  install_name_tool -delete_rpath '@loader_path/../lib' \
    "$macos_dir/tl866_probe" 2>/dev/null || true
  install_name_tool -add_rpath '@loader_path/../Frameworks' \
    "$macos_dir/minipro" 2>/dev/null || true
  install_name_tool -add_rpath '@loader_path/../Frameworks' \
    "$macos_dir/tl866_probe" 2>/dev/null || true
  install_name_tool -change '@rpath/libusb-1.0.0.dylib' \
    '@rpath/libusb-1.0.0.dylib' "$macos_dir/minipro" 2>/dev/null || true
  install_name_tool -change '@rpath/libusb-1.0.0.dylib' \
    '@rpath/libusb-1.0.0.dylib' "$macos_dir/tl866_probe" 2>/dev/null || true

  for artifact in "$macos_dir/minipro" "$macos_dir/tl866_probe" \
      "$frameworks_dir/libusb-1.0.0.dylib"; do
    if [[ "$(lipo -archs "$artifact")" != 'arm64' ]]; then
      print -u2 "Bundled native artifact is not arm64-only: $artifact"
      exit 1
    fi
  done
  otool -L "$macos_dir/minipro" "$macos_dir/tl866_probe" | \
    grep -q '@rpath/libusb-1.0.0.dylib'
  otool -l "$macos_dir/minipro" | grep -A2 LC_RPATH | \
    grep -q '@loader_path/../Frameworks'
  otool -l "$macos_dir/tl866_probe" | grep -A2 LC_RPATH | \
    grep -q '@loader_path/../Frameworks'
  {
    cat "$native_prefix/BUILD-MANIFEST.txt"
    shasum -a 256 "$macos_dir/minipro" | awk '{print "bundled_minipro_sha256=" $1}'
    shasum -a 256 "$macos_dir/tl866_probe" | awk '{print "bundled_tl866_probe_sha256=" $1}'
    shasum -a 256 "$frameworks_dir/libusb-1.0.0.dylib" | awk '{print "bundled_libusb_sha256=" $1}'
    shasum -a 256 "$resources_dir/infoic.xml" | awk '{print "bundled_infoic_xml_sha256=" $1}'
    shasum -a 256 "$resources_dir/logicic.xml" | awk '{print "bundled_logicic_xml_sha256=" $1}'
  } > "$resources_dir/BUILD-MANIFEST.txt"
}

sign_and_verify_app() {
  local app_path="$1"
  local frameworks_dir="$app_path/Contents/Frameworks"
  local macos_dir="$app_path/Contents/MacOS"

  # Sign from the innermost code outward. Frameworks and dylibs receive no
  # app entitlements; both Process-launched helpers inherit the app sandbox.
  while IFS= read -r -d '' nested; do
    sign_code "$nested"
  done < <(find "$frameworks_dir" -mindepth 1 -maxdepth 1 \
    \( -name '*.framework' -o -name '*.dylib' \) -print0)
  sign_code "$macos_dir/minipro" --entitlements "$helper_entitlements"
  sign_code "$macos_dir/tl866_probe" --entitlements "$helper_entitlements"
  sign_code "$app_path" --entitlements "$app_entitlements"
  codesign --verify --deep --strict --verbose=2 "$app_path"
}

cd "$project_dir"
zsh "$project_dir/tool/build_native_macos.sh"
"$flutter_bin" pub get
"$flutter_bin" build macos --release
bundle_native_payload "$release_app"
sign_and_verify_app "$release_app"

mkdir -p "$output_dir"
stage_dir=$(mktemp -d "$output_dir/.mushagaeshi-stage.XXXXXX")
staged_app="$stage_dir/$app_name"
ditto "$release_app" "$staged_app"

# Flutter's incremental build can update App.framework after Xcode signs it.
# Sign every embedded framework first, then the containing app. The outer app
# keeps the configured sandbox and user-selected-file entitlement.
sign_and_verify_app "$staged_app"

previous_app=''
if [[ -e "$target_app" ]]; then
  previous_app="$stage_dir/previous.app"
  mv "$target_app" "$previous_app"
fi
if ! mv "$staged_app" "$target_app"; then
  if [[ -n "$previous_app" ]]; then
    mv "$previous_app" "$target_app"
  fi
  exit 1
fi
if ! codesign --verify --deep --strict --verbose=2 "$target_app"; then
  mv "$target_app" "$stage_dir/failed.app"
  if [[ -n "$previous_app" ]]; then
    mv "$previous_app" "$target_app"
  fi
  exit 1
fi

print "Created and verified $target_app"
