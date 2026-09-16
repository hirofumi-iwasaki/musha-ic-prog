# v0.2.0 implementation record

## Scope

The accepted five-target design is implemented on `release/0.2.0`: macOS ARM64, Windows x64/ARM64 and Ubuntu x64/ARM64. The version is `0.2.0+2`. This work does not add programmer models, device families or physical SRAM/logic operations.

## Implementation

- Shared desktop host contract for file drops and asynchronous close requests. Busy operations and active confirmations veto window close on all runners.
- OS-aware native payload resolution and UTF-8 process output; Windows uses SetupAPI instance identities and WinUSB interface readiness, while Unix keeps its USB bus/address identity.
- Native Windows runner, approved ICO artwork, Unicode drops and a UTF-8 filesystem patch for the pinned minipro helper. Both helpers are built as native PE executables for the selected processor.
- Native GTK runner, approved Linux icons and logical-coordinate file drops. Scoped udev rules are provided for manual installation.
- Matching source, licenses, dependency manifests and checksums in all distributions. The verified pinned minipro source archive is versioned to avoid dependence on an interactive upstream download service.
- Five-target GitHub Actions matrix. Linux is built on Ubuntu 22.04 and launch-checked on Ubuntu 24.04. Only published-release events attach the full five-archive set; branch runs produce Actions artifacts.

## Validation in progress

Local Flutter analysis and all 57 tests passed, including shared payload resolution, Windows discovery fixtures and operation-aware close handling. CI repeats these checks for every target. macOS ARM64 and Ubuntu x64/ARM64 packaging have passed. Ubuntu 24.04 x64/ARM64 package checksum and headless launch checks also passed in run `35067786600`. Windows native packaging is under validation; the patched 20 C translation units pass syntax checks against the pinned Windows toolchain headers for both architectures. Final CI evidence will be recorded here.

## Outstanding acceptance

Build success is separate from physical support validation. The following remain required on each new Windows/Ubuntu target:

1. Driver binding or USB access setup; zero/one/multiple devices, wrong model, firmware errors, disconnect and reconnect.
2. Native GUI launch, scaling, arbitrary-extension file loading, Unicode/spaced paths, left-only drop, close while busy and error recovery.
3. Repeat reads and comparison using an approved exact IC profile; blank check and separately authorized destructive programming with complete readback comparison.
4. Record OS, architecture, application commit, firmware, full IC part number, adapter, source checksum and results in the hardware validation record.

No physical IC operations were executed by the cross-platform CI. Windows driver GUID compatibility is a required acceptance gate, not established by compiling the SetupAPI probe. macOS hardware regression remains separate from package compilation. No v0.2.0 release or merge is performed by this implementation task.
