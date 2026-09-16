# Rebuilding the bundled native payload

## macOS ARM64

The initial native payload is **arm64 only**, with a macOS 15.0 deployment
target. It is not a universal binary and it has not yet passed the physical
TL866CS M0 validation gate.

From a clean checkout on Apple Silicon with Xcode command-line tools:

```sh
tool/fetch_native_sources.sh
tool/materialize_minipro_sram.sh
tool/build_native_macos.sh
```

The first command copies the vendored, verified minipro archive and downloads
the official libusb release archive named in
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
root. GTK 3, EGL/OpenGL, LZMA, glibc, and normal Ubuntu desktop dependencies remain system
requirements and are not bundled.

## Windows x64 and ARM64

Use a native host for the target architecture with Visual Studio C++ desktop
build tools, Git for Windows, GNU make and the pinned Flutter SDK. CI's
`tool/ci/bootstrap_flutter.ps1` records the exact SDK revision and checks its
architecture. From PowerShell:

```powershell
tool/build_windows.ps1 -Architecture x64 -FlutterBin C:\path\to\flutter\bin\flutter.bat
# On a Windows ARM64 host, use -Architecture arm64.
```

The native build copies the verified minipro archive from
`third_party/minipro/source/`, applies the SRAM overlay and
`native/windows/minipro-utf8-paths.patch`, and builds minipro plus the
SetupAPI probe with pinned LLVM-MinGW. Windows explicitly selects
`src/usb_nix.c` instead of the legacy TL866A/CS vendor-driver transport in
`src/usb_win.c`. It builds pinned zlib statically and libusb 1.0.29 as a shared
DLL using Visual Studio MSBuild (`Release-MT`, v143, matching x64/ARM64 target).
The libusb archive is SHA-256 verified using `third_party/libusb/UPSTREAM.toml`'s
pinned hash. The DLL is installed beside `native/minipro.exe`; packaging checks
both its PE architecture and MiniPro's libusb import. The matching libusb source
archive and LGPL license are included in the distribution.
No MSYS/Cygwin runtime is included. The original native archives, patch,
probe and rebuild scripts are retained under `SOURCE/` in the ZIP.
Driver binding is a separate manual setup and hardware acceptance step;
see `native/windows/README.md`.
