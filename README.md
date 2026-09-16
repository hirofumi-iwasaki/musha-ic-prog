# Mushagaeshi IC Programmer

A desktop EPROM and memory IC programmer with a read-only hexadecimal viewer and comparison tools.

Repository: [hirofumi-iwasaki/musha-ic-prog](https://github.com/hirofumi-iwasaki/musha-ic-prog)

The first release targets macOS and the TL866CS. The Dart / Flutter architecture allows additional programmer backends, such as the XGecu T56, and future Windows / Linux versions. The viewer follows the presentation approach of [Mushagaeshi Binary Editor](https://github.com/hirofumi-iwasaki/musha-bin-editor).

## v0.1.0 release status

The macOS GitHub Actions build, static analysis, tests and release asset upload have passed. Local validation also covered the packaged application's signature and distribution checksums. The approved castle-and-EPROM artwork is included in the macOS application icon.

A user reported successfully reading a 27C512 using a connected TL866CS. This is a device-specific report, not validation of every catalog entry or operation. Eligible DIP memory devices are available for evaluation; logic IC tests and TL866CS SRAM pin control are not implemented in the app.

## Requirements

- macOS 15 or later; Apple Silicon (M1 or later)
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

## Features

- TL866CS detection through bundled, pinned minipro and libusb components
- Programmer, vendor and device selection with device search
- Full pinned minipro catalog: 81,763 aliases; 14,497 entries across 141 vendors for TL866CS
- IC reading, blank checking, comparison and confirmation-based programming for eligible memory profiles
- Separate bordered **Input BIN** and **IC Readout** panes
- Read-only hexadecimal and ASCII display, plus binary and decimal values for the selected byte
- Side-by-side SHA-1 values, with differing values highlighted in the same azuki color as byte differences
- Eight or sixteen bytes per row, synchronized scrolling, address navigation and difference navigation
- Left-pane Finder drag-and-drop and extension-independent file opening
- Connection and operation status, including a warning while the programmer is busy

Catalog presence does not mean a device has passed hardware validation. Aliases and upstream custom definitions are retained, including entries with similar names from different sources.

## GitHub Actions builds

The **Publish macOS release** workflow runs when a GitHub Release is published, including a pre-release, and supports manual dispatch. It uses a native Apple Silicon `macos-15` runner and Flutter 3.47.4 pinned to revision `9584c6713b324636289d067944a46fd6b49df14b`.

Each run resolves dependencies, performs static analysis and tests, builds the app, inspects its architecture and signature, and packages the complete runtime. Release-triggered runs attach `musha-ic-prog-macos-arm64.zip` to the release. Manual runs upload an Actions artifact without changing a release; availability in GitHub's UI depends on the workflow being present on the default branch.

Distribution names follow `musha-ic-prog-[OS]-[arch]`, with an appropriate archive extension. Only `macos-arm64` is currently provided. The ZIP includes the application, `LICENSE`, `THIRD_PARTY_NOTICES.txt`, `THIRD_PARTY_LICENSES/`, `SOURCE_AND_BUILD.txt`, `SHA256SUMS.txt`, and corresponding application and native dependency sources under `SOURCE/`.

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

See [native rebuilding instructions](third_party/NATIVE_REBUILDING.md) and the [minipro SRAM overlay](third_party/minipro/README.md) for dependency and fork details.

## Validation

```sh
flutter analyze
flutter test
sh tool/test_sram.sh
```

The Flutter suite contains 51 tests covering controller behavior, profile mapping, minipro process handling, binary comparison and native drop messages. The separate SRAM engine uses simulated memory tests; it is not connected to TL866CS hardware operations. The [hardware validation record](.chatgpt/TL866CS_HARDWARE_VALIDATION.md) distinguishes connection checks, user reports and outstanding device-specific validation.

## Architecture and current limitations

- `lib/core`: device profiles, catalogs and programmer models
- `lib/infrastructure`: programmer backends and minipro process execution
- `lib/application`: operation control and supported-profile mapping
- `lib/presentation`: device selection, binary viewer and status display
- `macos/Runner`: native window configuration, file drops and sandbox integration
- `native`: USB connection probe
- `third_party`: pinned dependency manifests, licenses and SRAM extension sources

The viewer keeps data in memory with a 64 MiB limit. Binary editing, a Save Readout interface, copying and paged reads are not implemented. Files are compared by offset; insertions and deletions are not realigned.

TL866CS is the only selectable programmer. T56 support, Windows / Linux builds, logic IC execution and physical SRAM testing are future work. The SRAM test engine exists as a separate extension foundation. Physical operation availability and empirical device validation are tracked separately.

## License

Project-authored code and documents are licensed under **GNU GPL version 3 or later (GPL-3.0-or-later)**. See [LICENSE](LICENSE). Third-party code, databases and assets retain their original licenses and notices.

The distribution includes matching minipro / libusb sources, the SRAM overlay and rebuilding instructions. See the [minipro license review](.chatgpt/MINIPRO_LICENSE_REVIEW.md) for the recorded dependency policy.

Design decisions and work records are maintained in `.chatgpt/`, including the [design](.chatgpt/DESIGN.md), [viewer and IC test plan](.chatgpt/VIEWER_AND_IC_TESTS.md) and [decisions](.chatgpt/DECISIONS.md).
