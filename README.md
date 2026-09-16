# Mushagaeshi IC Programmer

A desktop EPROM and memory IC programmer with a read-only hexadecimal viewer and comparison tools.

Repository: [hirofumi-iwasaki/musha-ic-prog](https://github.com/hirofumi-iwasaki/musha-ic-prog)

Version 0.2.0 extends the TL866CS application to five native targets: macOS ARM64, Windows x64/ARM64 and Ubuntu x64/ARM64. The ports are being validated; CI compilation and physical USB acceptance are tracked separately. The Dart / Flutter architecture allows additional programmer backends, such as the XGecu T56, across all supported operating systems. The viewer follows the presentation approach of [Mushagaeshi Binary Editor](https://github.com/hirofumi-iwasaki/musha-bin-editor).

## v0.2.0 release status

The republished [v0.2.0 Release](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.2.0) includes the corrected Windows TL866CS transport: bundled libusb with Microsoft's WinUSB driver. Windows requires a one-time driver assignment; Ubuntu may require USB access rules. Replace any archive downloaded before this correction.

All five corrected targets and both Ubuntu 24.04 launch checks passed [automated validation](https://github.com/hirofumi-iwasaki/musha-ic-prog/actions/runs/35074949228). Automated builds do not establish physical USB acceptance. See the [implementation record](.chatgpt/IMPLEMENTATION_0.2.0.md) and [Windows setup notes](native/windows/README.md). No new device families or physical SRAM/logic tests are enabled by this port.

## v0.1.0 release evidence

The macOS GitHub Actions build, static analysis, tests and release asset upload have passed. Local validation also covered the packaged application's signature and distribution checksums. The approved castle-and-EPROM artwork is included in the macOS application icon.

A user reported successfully reading a 27C512 using a connected TL866CS. This is a device-specific report, not validation of every catalog entry or operation. Eligible DIP memory devices are available for evaluation; logic IC tests and TL866CS SRAM pin control are not implemented in the app.

## Requirements

- macOS 15 or later; Apple Silicon (M1 or later)
- Windows 11 x64 or ARM64, or Ubuntu 22.04 / 24.04 LTS x64 or ARM64 for the new ports
- TL866CS connected over USB for IC operations
- No Flutter, Homebrew, minipro or libusb installation is needed to run the packaged app

Development uses Flutter 3.47.4, Dart 3.13.3 and Xcode. Hardware connection was checked on macOS 27.0 (26A428), with TL866CS firmware 03.2.86 (0x256). macOS 15 / 26 GUI and hardware acceptance remain separate from CI compilation.

## Run the macOS app

Download `musha-ic-prog-macos-arm64.zip` from [Releases](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases), extract it and open **Mushagaeshi IC Programmer.app**. You can copy the app to your Applications folder.

The locally packaged application is available at:

```text
dist/Mushagaeshi IC Programmer.app
```

```sh
open 'dist/Mushagaeshi IC Programmer.app'
```

The current application uses ad-hoc signing and has not been notarized by Apple. App Sandbox remains enabled.

Select **Open BIN**, or drop one file onto the left **Input BIN** pane. Any file extension is accepted; contents are read as raw bytes, without interpreting formats such as Intel HEX. Select the exact vendor and device before performing an IC operation, and confirm the device placement. Programming requires an additional confirmation. Do not touch the programmer, IC or USB connection while an operation is running.

## Run the Windows or Ubuntu app

Download the archive matching your OS and processor from [v0.2.0 Releases](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.2.0). Extract the complete directory; keep the executable beside its bundled libraries, `native/` and `resources/` directories.

- Windows: open `mushagaeshi_ic_programmer.exe`. USB operations require assigning the Windows WinUSB driver to TL866CS once, following the [Windows setup notes](native/windows/README.md). The same notes are included as `resources/minipro/WINDOWS_USB_SETUP.md`. A native ARM64 build does not validate the driver binding by itself.
- Ubuntu: run `mushagaeshi_ic_programmer` from an extracted desktop bundle. Install the distribution's GTK 3, EGL/OpenGL and LZMA runtime libraries (`libgtk-3-0`, `libegl1`, `libgles2`, `libgl1-mesa-dri`, `liblzma5`) and follow the [USB access instructions](linux/udev/README.md) if permission is denied. Do not run the application as root.

Windows and Ubuntu physical USB acceptance remains pending. The same file viewer and operation confirmation flow is used on every target.

## Features

- TL866CS detection through bundled, pinned minipro and libusb components
- Programmer, vendor and device selection with device search
- Full pinned minipro catalog: 81,763 aliases; 14,497 entries across 141 vendors for TL866CS
- IC reading, blank checking, comparison and confirmation-based programming for eligible memory profiles
- Separate bordered **Input BIN** and **IC Readout** panes
- Read-only hexadecimal and ASCII display, plus binary and decimal values for the selected byte
- Side-by-side SHA-1 values, with differing values highlighted in the same azuki color as byte differences
- Eight or sixteen bytes per row, synchronized scrolling, address navigation and difference navigation
- Left-pane file drag-and-drop and extension-independent file opening
- Connection and operation status, including a warning while the programmer is busy

Catalog presence does not mean a device has passed hardware validation. Aliases and upstream custom definitions are retained, including entries with similar names from different sources.

## GitHub Actions builds

The **Desktop build and package** workflow runs on pushes to `release/0.2.0`, pull requests, published Releases and manual dispatch. It builds all five targets using native runners and Flutter 3.47.4 pinned to revision `9584c6713b324636289d067944a46fd6b49df14b`. Ubuntu packages are built on 22.04 and also undergo headless launch checks on 24.04.

| Target | Archive |
| --- | --- |
| macOS ARM64 | `musha-ic-prog-macos-arm64.zip` |
| Windows x64 | `musha-ic-prog-windows-x64.zip` |
| Windows ARM64 | `musha-ic-prog-windows-arm64.zip` |
| Ubuntu x64 | `musha-ic-prog-linux-x64.tar.gz` |
| Ubuntu ARM64 | `musha-ic-prog-linux-arm64.tar.gz` |

Each build performs analysis, tests, native packaging and architecture checks. All five packages must build successfully before the release upload job runs. Manual and branch runs only produce Actions artifacts. CI does not perform physical IC operations or establish GUI/hardware acceptance.

Each archive contains the complete runtime, licenses/notices, `SOURCE_AND_BUILD.txt`, matching sources under `SOURCE/`, and `SHA256SUMS.txt`. Windows uses WinUSB from the OS; no MSYS/Cygwin runtime is required to run the app. Ubuntu requires its GTK desktop libraries and appropriate USB access. The application does not automatically install drivers or access rules.

## Development and packaging

With Flutter 3.47.4 installed, run from the repository root:

```sh
flutter pub get
flutter run -d macos
```

Use the packaging script for an application with the native programmer components included:

```sh
FLUTTER_BIN=flutter zsh tool/build_macos.sh
```

Create the complete distribution ZIP:

```sh
FLUTTER_BIN=flutter zsh tool/package_macos.sh
```

`FLUTTER_BIN` can also point to an absolute Flutter executable path. The scripts build pinned minipro and libusb sources locally, verify their download hashes, retain sandbox entitlements and sign the complete application. Output is written to `dist/`; `build/`, `dist/` and `.tooling/` are excluded from Git.

Windows packaging uses `tool/build_windows.ps1 -Architecture x64` (or `arm64`) from PowerShell on the matching native host. Ubuntu packaging uses `FLUTTER_BIN=flutter bash tool/build_linux.sh x64` (or `arm64`) on the matching Ubuntu 22.04 host. The [CI workflow](.github/workflows/desktop-build.yml) records prerequisites and the pinned Flutter bootstrap commands.

See [native rebuilding instructions](third_party/NATIVE_REBUILDING.md) and the [minipro SRAM overlay](third_party/minipro/README.md) for dependency and fork details.

## Validation

```sh
flutter analyze
flutter test
sh tool/test_sram.sh
```

The Flutter suite covers controller behavior, profile mapping, minipro process handling, binary comparison and native drop messages. The separate SRAM engine uses simulated memory tests; it is not connected to TL866CS hardware operations. The [hardware validation record](.chatgpt/TL866CS_HARDWARE_VALIDATION.md) distinguishes connection checks, user reports and outstanding device-specific validation.

## Architecture and current limitations

- `lib/core`: device profiles, catalogs and programmer models
- `lib/infrastructure`: programmer backends and minipro process execution
- `lib/application`: operation control and supported-profile mapping
- `lib/presentation`: device selection, binary viewer and status display
- `macos/Runner`, `windows/runner`, `linux`: native windows, file drops and coordinated close requests
- `lib/platform`: shared desktop host contract and operation-aware close handling
- `native`: USB connection probe
- `third_party`: pinned dependency manifests, licenses and SRAM extension sources

The viewer keeps data in memory with a 64 MiB limit. Binary editing, a Save Readout interface, copying and paged reads are not implemented. Files are compared by offset; insertions and deletions are not realigned.

TL866CS is the only selectable programmer. T56 support, logic IC execution and physical SRAM testing are future work. Windows/Linux hardware validation is recorded separately for each architecture. The SRAM test engine exists as a separate extension foundation. Physical operation availability and empirical device validation are tracked separately.

## License

Project-authored code and documents are licensed under **GNU GPL version 3 or later (GPL-3.0-or-later)**. See [LICENSE](LICENSE). Third-party code, databases and assets retain their original licenses and notices.

The distribution includes matching minipro / libusb sources, the SRAM overlay and rebuilding instructions. See the [minipro license review](.chatgpt/MINIPRO_LICENSE_REVIEW.md) for the recorded dependency policy.

Design decisions and work records are maintained in `.chatgpt/`, including the [design](.chatgpt/DESIGN.md), [viewer and IC test plan](.chatgpt/VIEWER_AND_IC_TESTS.md) and [decisions](.chatgpt/DECISIONS.md).
