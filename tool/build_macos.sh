#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
flutter_bin=${FLUTTER_BIN:-flutter}
output_dir=${1:-"$project_dir/dist"}
app_name='Mushagaeshi IC Programmer.app'
release_app="$project_dir/build/macos/Build/Products/Release/$app_name"
target_app="$output_dir/$app_name"
stage_dir=''

cleanup() {
  if [[ -n "$stage_dir" && -d "$stage_dir" ]]; then
    rm -rf "$stage_dir"
  fi
}
trap cleanup EXIT

sign_and_verify_app() {
  local app_path="$1"
  while IFS= read -r -d '' nested; do
    codesign --force --sign - --timestamp=none "$nested"
  done < <(find "$app_path/Contents/Frameworks" -mindepth 1 -maxdepth 1 \
    \( -name '*.framework' -o -name '*.dylib' \) -print0)
  codesign --force --sign - --timestamp=none \
    --entitlements "$project_dir/macos/Runner/Release.entitlements" "$app_path"
  codesign --verify --deep --strict --verbose=2 "$app_path"
}

cd "$project_dir"
"$flutter_bin" pub get
"$flutter_bin" build macos --release
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
