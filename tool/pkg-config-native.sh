#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Minimal build-only pkg-config adapter for the two minipro dependencies.
set -euo pipefail

: "${MUSHA_NATIVE_PREFIX:?MUSHA_NATIVE_PREFIX must name the local libusb prefix}"
module="${@: -1}"
case "$module" in
  libusb-1.0)
    if [[ " $* " == *' --cflags '* ]]; then
      print -- "-I$MUSHA_NATIVE_PREFIX/include/libusb-1.0"
    elif [[ " $* " == *' --libs '* ]]; then
      print -- "-L$MUSHA_NATIVE_PREFIX/lib -lusb-1.0"
    fi
    ;;
  zlib)
    if [[ " $* " == *' --libs '* ]]; then
      print -- '-lz'
    fi
    ;;
  *)
    # minipro also asks pkg-config about optional Linux install locations.
    # Empty output is the intended macOS answer.
    ;;
esac
