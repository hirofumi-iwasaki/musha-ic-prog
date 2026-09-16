#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

repo_dir=${0:A:h:h}
source_dir="$repo_dir/.tooling/native-src"
libusb_archive="$source_dir/libusb-1.0.29.tar.bz2"
libusb_sha256='5977fc950f8d1395ccea9bd48c06b3f808fd3c2c961b44b0c2e6e29fc3a70a85'
libusb_url='https://github.com/libusb/libusb/releases/download/v1.0.29/libusb-1.0.29.tar.bz2'
minipro_commit='cae74c0607077d6260b24995f5e4c0d0b66a6a2e'
minipro_archive="$source_dir/minipro-$minipro_commit.tar.gz"
minipro_sha256='6363acb0b69f6038ff7a64a751bd2b4fa671debde487c83fd4c5c876c95175af'
minipro_url="https://gitlab.com/DavidGriffith/minipro/-/archive/$minipro_commit/minipro-$minipro_commit.tar.gz"

mkdir -p "$source_dir"
if [[ ! -f "$libusb_archive" ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 --output "$libusb_archive" "$libusb_url"
fi
if [[ ! -f "$minipro_archive" ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 --output "$minipro_archive" "$minipro_url"
fi

actual_sha256=$(shasum -a 256 "$libusb_archive" | awk '{print $1}')
if [[ "$actual_sha256" != "$libusb_sha256" ]]; then
  print -u2 "libusb source hash mismatch: expected $libusb_sha256, got $actual_sha256"
  exit 1
fi
actual_sha256=$(shasum -a 256 "$minipro_archive" | awk '{print $1}')
if [[ "$actual_sha256" != "$minipro_sha256" ]]; then
  print -u2 "minipro source hash mismatch: expected $minipro_sha256, got $actual_sha256"
  exit 1
fi
print "Verified $libusb_archive"
print "Verified $minipro_archive"
