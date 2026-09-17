# v0.2.0 five-platform design

Status: **Accepted implementation direction**, 2026-09-16. Implementation and native acceptance are pending.
Branch: `release/0.2.0`, created from merged `main` at `2754f879d1cdf2b71d7ac92c2fddeb94ce89b57b`.
This document governs v0.2.0 platform work and extends the v0.1.0 design. It does not declare untested targets supported.

## 1. Scope and release matrix

Keep one Dart / Flutter application and the current TL866CS feature set. ARM means native **ARM64**, not ARM32 or an emulated x64 application. Linux follows Binary Editor's Ubuntu baseline.

| Release target | Product baseline | Native build runner | Asset |
| --- | --- | --- | --- |
| macOS ARM64 | macOS 15 / 26, Apple Silicon | `macos-15` | `musha-ic-prog-macos-arm64.zip` |
| Windows x64 | Windows 11 x64 | `windows-2022` | `musha-ic-prog-windows-x64.zip` |
| Windows ARM64 | Windows 11 ARM64 | `windows-11-arm` | `musha-ic-prog-windows-arm64.zip` |
| Linux x64 | Ubuntu 22.04 / 24.04 LTS | `ubuntu-22.04` | `musha-ic-prog-linux-x64.tar.gz` |
| Linux ARM64 | Ubuntu 22.04 / 24.04 LTS | `ubuntu-22.04-arm` | `musha-ic-prog-linux-arm64.tar.gz` |

Five artifacts, not five OS versions. Ubuntu 24.04 adds acceptance/test jobs for both architectures without duplicate release artifacts. Windows Server CI compilation is not Windows 11 desktop acceptance. macOS 27 evidence from v0.1.0 does not replace the 15/26 matrix.

Do not add T56, binary editing, physical SRAM/logic testing, automatic firmware updates, erase operations or expanded memory eligibility in this portability release. Windows 10, macOS Intel and other Linux distributions are outside the initial commitment. Existing 64 MiB limit, SHA-1 display, read-only viewer, catalog and confirmation behavior remain.

## 2. Reference implementation and findings

Reviewed Binary Editor's README, `.chatgpt/CROSS_PLATFORM_DESIGN.md`, `.github/workflows/desktop-ci.yml`, native runners and `tool/build_windows.ps1`, `tool/build_linux.sh`, `tool/package_macos.sh`.

Reuse its native-per-architecture Flutter bootstrap, complete-runtime packaging, PE/ELF inspection, icon formats and OS integration approach. Do not copy its editing/save transaction or unrelated update checker into this app.

Current IC Programmer portability seams:

- `MiniproPaths.bundled()` assumes `Contents/MacOS` and `Contents/Resources`.
- `ProcessRunner` already accepts executable, arguments, environment and working directory; retain this boundary.
- `ProgrammerScreen` owns macOS drop MethodChannel handling; move it behind a desktop integration contract.
- `native/tl866_probe.c` enumerates libusb descriptors without opening the device; currently built only for macOS.
- Catalog and eligibility mapping are shared Dart logic and must remain identical across targets.
- Existing scripts build an ARM64 native payload, sign a macOS bundle and copy selected macOS sources. New runners and all platform build inputs must be included in corresponding-source packages.

**Corrected source finding (D30):** pinned `src/usb_win.c` uses legacy vendor IOCTLs for TL866A/CS; its WinUSB path is for other models. The initial assumption below has been superseded. Windows now compiles `src/usb_nix.c` with bundled libusb 1.0.29 and a WinUSB driver binding. macOS/Linux retain their libusb transport.

## 3. Shared architecture

Keep core, infrastructure, application and presentation layers. Compose platform adapters in `main.dart`; no scattered OS conditions in widgets.

| Contract | Responsibility |
| --- | --- |
| `NativePayloadLocator` | Resolve absolute bundled executable/database/library locations; validate OS/architecture manifest and required files |
| `ProgrammerDiscovery` | Enumerate candidates without IC operations; return distinct missing-device, driver, permission, busy and helper-error states |
| `DesktopFileAccess` | Existing file selector plus one-file pane drop, optional macOS access lease |
| `WindowOperationLifecycle` | Defer normal close/quit while hardware command is active; complete at a command boundary |
| `ProcessRunner` | Shell-free native process execution and bounded output capture; injectable in tests |

Preserve `ProgrammerBackend` / capability separation for future models. Add platform-qualified runtime readiness separately from `evaluationAuthorized` and device `verified`; neither OS support nor catalog presence grants empirical IC validation.

Normalize paths with the Dart `path` package and file URI conversion. Windows Unicode/space paths must work both for app location and user files. If pinned minipro's narrow filename APIs fail non-ASCII paths, patch the fork's Windows file-opening boundary to UTF-8/UTF-16 APIs; do not silently copy user data to a guessed ASCII system path. Run subprocesses with argument lists, no shell, absolute executable/database paths and an explicit working directory. Never search the current directory or PATH for a replacement minipro. Decode process output consistently and test CRLF/progress/exit differences.

A per-operation private temporary directory holds input snapshots and readback. Close and flush files before invoking helpers; Windows may refuse open-handle replacement/deletion. Cleanup failure must not conceal the operation result. Drain stdout/stderr while bounding retained logs. User cancellation and window close take effect between hardware commands, never via an ordinary forced kill during programming. OS-forced termination cannot guarantee IC state; explain recovery without claiming safe interruption.

## 4. Native payloads and USB

### macOS

Keep the working `.app` layout, ARM64 helper/libusb payload, sandbox USB entitlement and helper inheritance. Preserve existing signatures and native file-access scopes. Retain current ad-hoc signing policy unless signing/notarization is separately configured. A universal Flutter executable does not make the ARM64-only helper bundle Intel-compatible.

### Windows

Build Flutter runner/plugins with Visual Studio's native target toolchain. Build pinned minipro using its libusb transport (`USB=src/usb_nix.o`) and static zlib with LLVM-MinGW. Build libusb as a native Visual Studio Release-MT DLL for each architecture and place it beside minipro.exe. Pin source hashes, inspect PE architectures/imports, and include matching sources/licenses. No MSYS/Cygwin runtime dependency or emulated helper is shipped.

Implement a Windows read-only SetupAPI probe: enumerate present USB devices by VID `04d8` / PID `e11c`, report instance identity and bound service. WinUSB service readiness is a prerequisite, not proof of successful communication. libusb handles interface discovery; do not require the legacy vendor GUID. Retain the MiniPro model/firmware check and reject multiple candidates. No probe USB transfers or IC operations.

Use Microsoft's built-in WinUSB kernel driver with explicit Zadig setup instructions for x64/ARM64. Driver assignment is a separate user action; the app runs without elevation and never auto-replaces drivers. Zadig 2.8+ supports ARM64 WinUSB setup. Physical acceptance remains required on both architectures; preserve signature enforcement. See native/windows/README.md.

Portable layout: Flutter EXE/DLLs and `data/` at package root; `native/minipro.exe`, `native/tl866_probe.exe`, and required non-system DLLs together; `resources/minipro/` for databases. Validate direct and transitive DLL dependencies, UCRT/VC runtime prerequisites and clean-system execution. OS WinUSB/SetupAPI DLLs are not redistributed.

### Linux

Build minipro, libusb 1.0.29 and required zlib against Ubuntu 22.04 separately for x64 and ARM64. Keep glibc/GTK and their documented desktop dependencies as system requirements; do not bundle a newer glibc. Pin any bundled zlib source and record licenses/provenance rather than silently using a host-only library. Inspect every ELF and `ldd`/RPATH result for unresolved dependencies or developer-machine paths.

Portable layout: complete Flutter bundle at root, `native/minipro` and `native/tl866_probe`, shared native libraries in `lib/`, and `resources/minipro/` databases. Use executable-relative `$ORIGIN/../lib` resolution for helpers. Preserve executable bits and symlinks in tar.gz.

Reuse the descriptor-only libusb probe. Ship a narrowly scoped udev rule for TL866A/CS VID/PID, based on the pinned upstream rule and retaining its license: local-session `uaccess` plus documented group fallback where needed, never world-writable USB access. Installation and reconnect/reload are explicit administrator setup steps; never run the app as root or install rules silently. Distinguish enumeration from permission to open the device and show actionable English status. Verify both X11 and Wayland file drop/session permission behavior.

## 5. UI, desktop behavior and branding

Keep one-file drop on Input BIN only; reject directories, multiple files, right-pane drops and drops during operations/confirmation. Keep `file_selector` for dialogs. Adapt Binary Editor's working native runner drop implementation where compatible; if a package is adopted instead, require ARM64/x64 and license validation first. macOS scope acquisition/release remains native; Windows/Linux do not emulate security-scoped URLs.

Preserve bordered empty panes, azuki byte/hash differences, synchronized scrolling and 8/16-byte rows. Use measured monospace metrics with available OS fallback fonts, avoiding an assumption that Menlo exists. Verify byte hit testing, 100/150/200% scaling, long device names, Unicode paths, dark/light themes, wheel/trackpad/horizontal scrolling. Translate any implemented Command shortcuts to Ctrl on Windows/Linux; do not advertise new shortcuts without implementation.

Generate Windows multi-resolution ICO and Linux PNG/hicolor icons and desktop entry from approved v4 master. Preserve existing application display name and macOS identity; use stable `mushagaeshi_ic_programmer` executable/application identity for new targets. Linux launcher registration and Windows file associations/installers remain separate from extracting a portable archive. Public README, PR and Release notes remain English.

## 6. Build and release

Retain Flutter 3.47.4 / Dart 3.13.3 and pinned SDK revision from v0.1.0. Keep minipro/catalog revision unchanged during portability work unless a documented blocking fix requires otherwise. Add Windows/Linux native build scripts, runner generation, platform source packaging and generalized metadata. Toolchain/dependency versions and download hashes are committed once verified in the spike; no floating latest dependencies in release scripts.

CI: PRs and pushes to `release/0.2.0` build/test all five targets; additional Ubuntu 24.04 jobs check compatibility. Use native ARM64 runners and architecture checks for app, plugins, helper and non-system libraries. Emulated x64 execution is not ARM64 acceptance. Hosted runners cannot prove USB operation.

Replace the macOS-only release workflow with one five-target workflow, preserving release `published` and manual dispatch. Build all artifacts from the exact same tag SHA, then run a dependent upload job only after all five succeed. Never publish a partial target set as a complete release. Use minimal permissions: build jobs read contents, release upload job writes contents. Pass tag names through environment variables, not interpolated shell code. Manual dispatch produces artifacts without modifying a release. Draft/tag publication sequencing must be documented; if publication triggers the builds, a failed run leaves notes explicitly stating assets are incomplete until retry succeeds.

Each archive includes licenses/notices, dependency/source manifests, SHA-256 file checksums, exact source revision and matching application/native sources and rebuilding inputs for all platforms. SHA-1 remains the UI comparison hash only. Include Windows runtime/driver and Linux desktop/udev prerequisites. Preserve immutable released tags; fixes use a new reviewed commit/release rather than retargeting old tags. Release version/build metadata changes to 0.2.0 during implementation, not in this design-only task.

## 7. Work sequence and completion gates

| Phase | Deliverable | Exit criteria |
| --- | --- | --- |
| P0 | Native feasibility spike: Windows ARM64 first, then x64 and Linux | Pinned minipro/probe compiled; offline CLI/database lookup; architecture/import inspection; WinUSB binding and physical opening tested |
| P1 | Payload locator, discovery errors, file/drop and window adapters | Portable tests pass; macOS regression stays green; no silent mock fallback |
| P2 | Windows/Linux runners, icons and payloads | All five native builds and clean-system app launch without developer SDKs |
| P3 | USB integration | Each OS/arch detects one TL866CS, distinguishes permissions/driver errors, rejects wrong/multiple models |
| P4 | Hardware and UI acceptance | Per-target reference read/verify and approved write/readback; desktop/DPI/drop/close matrix |
| P5 | Five-asset release pipeline and English documentation | Same-SHA packages, unpacked checksum/dependency checks, all required acceptance records and complete assets |

Portable tests: locator fixtures for five layouts; Unicode paths; empty/missing payloads; probe JSON/error cases; CRLF and log decoding; failed subprocesses; cancellation boundaries; temp cleanup; one-file drop; immutable byte/hash/difference behavior; unchanged eligibility mapping. Separate OS-dependent tests instead of skipping broad suites silently.

Hardware acceptance per target: record OS/build, architecture, driver/rule version, minipro commit, firmware, full manufacturer/device alias, IC capacity and reference SHA-1. Read the same known EPROM repeatedly and compare with macOS reference bytes; blank check and verify must agree. Write tests use only an explicitly selected disposable/blank device with confirmed contents, followed by full readback. Exercise absent/unplugged/busy/reconnect states without intentionally interrupting an active write. VM USB passthrough must be recorded; pure CI success is insufficient. Mac regressions remain required.

No target is marked hardware-validated merely because another architecture passed. Missing native desktop/USB test environments remain explicit pending gates, not a reason to substitute emulation or hide a failed target. Development may proceed through P0–P2 without them.

## 8. References and evidence

Reviewed 2026-09-16:

- [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms): platform/architecture capability, not project-specific validation.
- [GitHub hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners): native runner labels; availability must also pass actual CI bootstrap.
- [libusb Windows notes](https://github.com/libusb/libusb/wiki/Windows): driver binding and WinUSB limitations; Windows uses the pinned minipro libusb transport after D30.
- [Microsoft WinUSB installation](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation): driver package/binding requirements.
- Local pinned minipro archive: `Makefile`, `src/usb_win.c`, `src/usb_nix.c`, `udev/60-minipro.rules`; manifest at `third_party/minipro/UPSTREAM.toml`.
- Binary Editor references listed in section 2. Its design/status and historical validation are reference material, not validation of this programmer app.
