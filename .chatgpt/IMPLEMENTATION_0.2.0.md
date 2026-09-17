# v0.2.0 implementation record

## Windows transport correction and release withdrawal

The initial release failed to communicate on the reported Windows ARM64 setup.
Source review found that `usb_win.c` uses legacy vendor IOCTLs for TL866A/CS;
the initial WinUSB assumption was incorrect. The user requested a fix and
withdrawal: GitHub Release v0.2.0 and its assets were deleted, retaining its tag
at `941f6f0fc7c33e768c8ae8c81ef0157710a56413` and open PR #2.

The correction selects MiniPro's libusb transport on Windows, bundles libusb
1.0.29 for each native architecture, removes legacy GUID gating and includes
WinUSB setup instructions. Prior build evidence below does not validate this
correction or physical USB communication. Updated validation is recorded below
when complete. Physical Windows/Linux IC acceptance remains pending.

## Scope

The accepted five-target design is implemented on `release/0.2.0`: macOS ARM64, Windows x64/ARM64 and Ubuntu x64/ARM64. The version is `0.2.0+2`. This work does not add programmer models, device families or physical SRAM/logic operations.

## Implementation

- Shared desktop host contract for file drops and asynchronous close requests. Busy operations and active confirmations veto window close on all runners.
- OS-aware native payload resolution and UTF-8 process output; Windows uses SetupAPI instance identities and WinUSB interface readiness, while Unix keeps its USB bus/address identity.
- Native Windows runner, approved ICO artwork, Unicode drops and a UTF-8 filesystem patch for the pinned minipro helper. Both helpers are built as native PE executables for the selected processor.
- Native GTK runner, approved Linux icons and logical-coordinate file drops. Scoped udev rules are provided for manual installation.
- Matching source, licenses, dependency manifests and checksums in all distributions. The verified pinned minipro source archive is versioned to avoid dependence on an interactive upstream download service.
- Five-target GitHub Actions matrix. Linux is built on Ubuntu 22.04 and launch-checked on Ubuntu 24.04. Only published-release events attach the full five-archive set; branch runs produce Actions artifacts.

## Automated validation completed

[GitHub Actions run 35069146880](https://github.com/hirofumi-iwasaki/musha-ic-prog/actions/runs/35069146880) succeeded for implementation commit `e383f61a7c7cc9921ae6155cef51766168a8fc3b` on 2026-09-16. All five native build jobs and both Ubuntu 24.04 compatibility jobs passed. The release upload job was correctly skipped because this was a branch build.

| Target | Build / package | Runtime evidence |
| --- | --- | --- |
| macOS ARM64 | Passed | Packaged application architecture/signature checks; manual hardware regression remains pending |
| Windows x64 | Passed | Native helper help, Unicode database lookup, SetupAPI JSON, complete PE/import checks, packaged GUI launch and normal close |
| Windows ARM64 | Passed | Same checks on native ARM64 runner; unused x64 CRT companion excluded by import inspection |
| Ubuntu x64 | Passed on 22.04 | Package checksum verification and headless launch on 24.04 |
| Ubuntu ARM64 | Passed on 22.04 | Package checksum verification and headless launch on 24.04 |

Every target passed static analysis and all 57 Flutter tests. Unix jobs also passed the standalone simulated SRAM engine tests. The patched 20 C translation units were syntax-checked against the pinned Windows toolchain headers for both Windows architectures before the native CI builds.

The successful run contains exactly these five Actions artifacts, each holding its corresponding archive:

- `musha-ic-prog-macos-arm64.zip`
- `musha-ic-prog-windows-x64.zip`
- `musha-ic-prog-windows-arm64.zip`
- `musha-ic-prog-linux-x64.tar.gz`
- `musha-ic-prog-linux-arm64.tar.gz`

The downloaded Windows ARM64 ZIP independently passed all 248 recorded file checksums and checks for matching source/native payloads. Its metadata records the exact implementation commit and a clean source worktree. The earlier Windows x64 ZIP from commit `e4e3f16` also passed all 252 checksums before unused CRT companions were removed.

This evidence records automated compilation and hosted runtime checks, not physical programmer acceptance. The initial v0.2.0 Release was subsequently published and then withdrawn; see the correction below.

## Outstanding acceptance

Build success is separate from physical support validation. The following remain required on each new Windows/Ubuntu target:

1. Driver binding or USB access setup; zero/one/multiple devices, wrong model, firmware errors, disconnect and reconnect.
2. Native GUI launch, scaling, arbitrary-extension file loading, Unicode/spaced paths, left-only drop, close while busy and error recovery.
3. Repeat reads and comparison using an approved exact IC profile; blank check and separately authorized destructive programming with complete readback comparison.
4. Record OS, architecture, application commit, firmware, full IC part number, adapter, source checksum and results in the hardware validation record.

No physical IC operations were executed by the cross-platform CI. Windows WinUSB/libusb communication is a required acceptance gate, not established by compiling the SetupAPI probe. macOS hardware regression remains separate from package compilation. The withdrawn release tag is retained; republication requires a new user instruction.

## Correction validation before hosted builds

Local static analysis passed and all 60 Flutter tests passed. The corrected
Windows native sources (20 C translation units per architecture) passed syntax
checks against the pinned LLVM-MinGW/libusb headers for x64 and ARM64. Packaging
now checks the libusb DLL import and architecture, includes the USB setup guide
and matching libusb source/license, and exercises libusb enumeration with no
programmer attached on hosted Windows runners. Hosted build results follow
separately; these checks do not validate physical TL866CS operations.

## Corrected transport: hosted validation passed

[Run 35074949228](https://github.com/hirofumi-iwasaki/musha-ic-prog/actions/runs/35074949228)
passed all five builds and both Ubuntu 24.04 checks for commit
`543ce2e0246863d0ace3a5fa40218b91899ad5a6`. Release upload was skipped as intended.
All targets passed analysis and 60 Flutter tests. Windows x64/ARM64 passed
libusb DLL import/architecture checks, verbose no-device USB enumeration,
Unicode database lookup, SetupAPI JSON and GUI launch/close checks. The libusb
MSVC operand-cast patch preserves the USB request value.

Downloaded Windows x64 and ARM64 archives independently passed all 254 and
253 file checksums respectively. Both contain the native libusb DLL, WinUSB
setup instructions, corresponding source archive/patch, licenses and a clean
source revision manifest. The duplicate PR run encountered a transient zlib
download hash mismatch; the check rejected that download and the job was
retried without changing the pinned hash. The successful branch run provides
the complete five-archive evaluation set.

The Release remains withdrawn and the old v0.2.0 tag remains unchanged. Windows
physical TL866CS recognition and approved IC read/compare still require user
acceptance; CI is not hardware evidence.
