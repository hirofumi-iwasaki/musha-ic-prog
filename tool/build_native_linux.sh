#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Build the pinned Unix payload on a native Ubuntu 22.04 x64 or ARM64 host.
set -euo pipefail
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
case "$(uname -m)" in x86_64) architecture=x64;; aarch64|arm64) architecture=arm64;; *) echo "Unsupported Linux host: $(uname -m)" >&2; exit 1;; esac
[[ ${1:-$architecture} == "$architecture" ]] || { echo "A native $1 Linux host is required." >&2; exit 1; }
libusb_version=1.0.29; libusb_sha256=5977fc950f8d1395ccea9bd48c06b3f808fd3c2c961b44b0c2e6e29fc3a70a85
minipro_commit=cae74c0607077d6260b24995f5e4c0d0b66a6a2e; minipro_sha256=6363acb0b69f6038ff7a64a751bd2b4fa671debde487c83fd4c5c876c95175af
zlib_version=1.3.2; zlib_sha256=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16
source_dir="$project_dir/.tooling/native-src"; prefix="$project_dir/.tooling/native-prefix-linux-$architecture"; work_dir=''; minipro_dir=''
cleanup() { [[ -n "$work_dir" && -d "$work_dir" ]] && rm -rf "$work_dir"; [[ -n "$minipro_dir" && -d "$minipro_dir" ]] && rm -rf "$minipro_dir"; }
trap cleanup EXIT HUP INT TERM
sha256() { sha256sum "$1" | awk '{print $1}'; }
fetch() { local file=$1 hash=$2 url=$3; [[ -f $file ]] || curl --fail --location --proto '=https' --tlsv1.2 --output "$file" "$url"; [[ $(sha256 "$file") == "$hash" ]] || { echo "Pinned source hash mismatch: $file" >&2; exit 1; }; }
mkdir -p "$source_dir"
fetch "$source_dir/libusb-$libusb_version.tar.bz2" "$libusb_sha256" "https://github.com/libusb/libusb/releases/download/v$libusb_version/libusb-$libusb_version.tar.bz2"
[[ -f "$source_dir/minipro-$minipro_commit.tar.gz" ]] || cp "$project_dir/third_party/minipro/source/minipro-$minipro_commit.tar.gz" "$source_dir/minipro-$minipro_commit.tar.gz"
fetch "$source_dir/minipro-$minipro_commit.tar.gz" "$minipro_sha256" "https://gitlab.com/DavidGriffith/minipro/-/archive/$minipro_commit/minipro-$minipro_commit.tar.gz"
fetch "$source_dir/zlib-$zlib_version.tar.gz" "$zlib_sha256" "https://zlib.net/zlib-$zlib_version.tar.gz"
rm -rf "$prefix"; mkdir -p "$prefix"
work_dir=$(mktemp -d "$project_dir/.tooling/.native-linux.XXXXXX")
tar -xjf "$source_dir/libusb-$libusb_version.tar.bz2" -C "$work_dir"; tar -xzf "$source_dir/zlib-$zlib_version.tar.gz" -C "$work_dir"
mkdir "$work_dir/libusb-build"
(cd "$work_dir/libusb-build" && "$work_dir/libusb-$libusb_version/configure" --prefix="$prefix" --disable-static --enable-shared)
make -C "$work_dir/libusb-build" -j"$(nproc)"; make -C "$work_dir/libusb-build" install
(cd "$work_dir/zlib-$zlib_version" && ./configure --prefix="$prefix")
make -C "$work_dir/zlib-$zlib_version" -j"$(nproc)"; make -C "$work_dir/zlib-$zlib_version" install
minipro_dir=$(mktemp -d "$project_dir/.tooling/.minipro-linux.XXXXXX")
tar -xzf "$source_dir/minipro-$minipro_commit.tar.gz" --strip-components=1 -C "$minipro_dir"
cp "$project_dir/third_party/minipro/sram/sram_test.c" "$minipro_dir/src/sram_test.c"; cp "$project_dir/third_party/minipro/sram/sram_test.h" "$minipro_dir/src/sram_test.h"
if ! grep -q 'src/sram_test.o' "$minipro_dir/Makefile"; then awk '/^COMMON_OBJECTS=/ {print; print "\t\tsrc/sram_test.o \\"; next} {print}' "$minipro_dir/Makefile" > "$minipro_dir/Makefile.new"; mv "$minipro_dir/Makefile.new" "$minipro_dir/Makefile"; fi
mkdir "$work_dir/bin"
cat > "$work_dir/bin/pkg-config" <<'EOF'
#!/usr/bin/env sh
set -eu
module=''; for argument; do module=$argument; done
case "$module" in
libusb-1.0) case " $* " in *' --cflags '*) echo "-I$MUSHA_NATIVE_PREFIX/include/libusb-1.0";; *' --libs '*) echo "-L$MUSHA_NATIVE_PREFIX/lib -lusb-1.0";; esac;;
zlib) case " $* " in *' --cflags '*) echo "-I$MUSHA_NATIVE_PREFIX/include";; *' --libs '*) echo "-L$MUSHA_NATIVE_PREFIX/lib -lz";; esac;;
esac
EOF
chmod 0755 "$work_dir/bin/pkg-config"
PATH="$work_dir/bin:$PATH" MUSHA_NATIVE_PREFIX="$prefix" make -C "$minipro_dir" clean
PATH="$work_dir/bin:$PATH" MUSHA_NATIVE_PREFIX="$prefix" make -C "$minipro_dir" CC=gcc CFLAGS='-O2' LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"
mkdir -p "$prefix/native" "$prefix/resources/minipro"
install -m 0755 "$minipro_dir/minipro" "$prefix/native/minipro"
gcc -O2 -I"$prefix/include/libusb-1.0" "$project_dir/native/tl866_probe.c" -L"$prefix/lib" -lusb-1.0 -Wl,-rpath,'$ORIGIN/../lib' -o "$prefix/native/tl866_probe"
for item in infoic.xml logicic.xml LICENSE README.md; do install -m 0644 "$minipro_dir/$item" "$prefix/resources/minipro/$item"; done
cmp -s "$prefix/resources/minipro/infoic.xml" "$project_dir/assets/minipro/infoic.xml"; cmp -s "$prefix/resources/minipro/logicic.xml" "$project_dir/assets/minipro/logicic.xml"
machine='Advanced Micro Devices X86-64'; [[ $architecture == arm64 ]] && machine='AArch64'
for artifact in "$prefix/native/minipro" "$prefix/native/tl866_probe" "$prefix/lib/libusb-1.0.so.0" "$prefix/lib/libz.so.1"; do
  [[ -e $artifact ]] || { echo "Missing $artifact" >&2; exit 1; }; readelf -h "$artifact" | grep -Fq "Machine:                           $machine" || { echo "Wrong ELF architecture: $artifact" >&2; exit 1; }; ldd "$artifact" | grep -q 'not found' && { echo "Unresolved dependency: $artifact" >&2; exit 1; } || true
done
for helper in "$prefix/native/minipro" "$prefix/native/tl866_probe"; do readelf -d "$helper" | grep -Eq 'RUNPATH.*\$ORIGIN/../lib' || { echo "Missing RPATH: $helper" >&2; exit 1; }; done
dynamic_entries=$(readelf -d "$prefix/native/minipro" "$prefix/native/tl866_probe" | awk '/\((NEEDED|RPATH|RUNPATH)\)/')
if grep -Fq "$project_dir" <<<"$dynamic_entries" || grep -Fq "$HOME" <<<"$dynamic_entries"; then
  echo 'Developer path in helper dynamic entries.' >&2
  exit 1
fi
cat > "$prefix/BUILD-MANIFEST.txt" <<EOF
target_os=linux
target_architecture=$architecture
ubuntu_build_baseline=22.04
libusb_version=$libusb_version
libusb_sha256=$libusb_sha256
zlib_version=$zlib_version
zlib_sha256=$zlib_sha256
minipro_commit=$minipro_commit
minipro_archive_sha256=$minipro_sha256
minipro_overlay=sram_test.c,sram_test.h
minipro_sram_test_c_sha256=$(sha256 "$project_dir/third_party/minipro/sram/sram_test.c")
minipro_sram_test_h_sha256=$(sha256 "$project_dir/third_party/minipro/sram/sram_test.h")
tl866_probe_c_sha256=$(sha256 "$project_dir/native/tl866_probe.c")
infoic_xml_sha256=$(sha256 "$prefix/resources/minipro/infoic.xml")
logicic_xml_sha256=$(sha256 "$prefix/resources/minipro/logicic.xml")
compiler=$(gcc --version | head -n 1)
EOF
printf 'Built Linux %s native payload at %s\n' "$architecture" "$prefix"
