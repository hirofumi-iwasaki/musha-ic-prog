# Rebuilding the bundled macOS native payload

The initial native payload is **arm64 only**, with a macOS 15.0 deployment
target. It is not a universal binary and it has not yet passed the physical
TL866CS M0 validation gate.

From a clean checkout on Apple Silicon with Xcode command-line tools:

```sh
tool/fetch_native_sources.sh
tool/materialize_minipro_sram.sh
tool/build_native_macos.sh
```

The first command downloads the exact official release archives named in
`third_party/libusb/UPSTREAM.toml` and `third_party/minipro/UPSTREAM.toml`,
then verifies their SHA-256 values. The second creates an ignored full minipro
source tree from that archive and applies the tracked SRAM overlay. The final
command builds shared libusb, minipro, and the read-only `tl866_probe` helper
under `.tooling/native-prefix/` without using a Homebrew runtime dependency.

`tool/build_macos.sh` repeats those preparation steps as needed and copies the
native payload, original XML databases, licenses, source manifests, and its
build manifest into the final app. Distribution must make the matching source
archives, this repository's overlay, and these rebuild instructions available.

## Linux x64 and ARM64

Build each archive on its matching native Ubuntu 22.04 host; x64 emulation is
not ARM64 validation. The Linux script fetches and verifies pinned libusb
1.0.29, zlib 1.3.2, and the pinned minipro source archive, builds their shared
libraries under `.tooling/native-prefix-linux-<arch>/`, and gives both helpers
an executable-relative `$ORIGIN/../lib` runpath:

```sh
tool/build_linux.sh x64
# On an Ubuntu ARM64 host:
tool/build_linux.sh arm64
```

The portable archive includes the Flutter bundle, helpers, shared libraries,
databases, matching native source trees, and the TL866A/CS udev rule. Install
the rule as described in `linux/udev/README.md`; do not run the application as
root. GTK 3, glibc, and normal Ubuntu desktop dependencies remain system
requirements and are not bundled.
