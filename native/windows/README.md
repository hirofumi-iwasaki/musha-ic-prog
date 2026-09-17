# Windows native payload

User installation, WinUSB assignment, ARM64 signature troubleshooting and restart
verification are maintained in the main [README](../../README.md#windows-installation).

## Rebuilding

`tool/build_native_windows.ps1 -Architecture x64` (or `arm64`) builds the pinned
MiniPro source with `src/usb_nix.c`, its libusb transport, on Windows. It does
not use `src/usb_win.c`, whose TL866A/CS branch requires legacy vendor IOCTLs.
MiniPro and the SetupAPI probe use LLVM-MinGW 20240619 UCRT; zlib 1.3.2 is linked
statically. libusb 1.0.29 is built as a native DLL with Visual Studio's
`Release-MT` configuration, so it does not need extra MSVC runtime DLLs beside
the helper. libusb remains a replaceable shared library.

The probe enumerates present USB devices by VID/PID and reports the Windows
instance identity and bound driver service. It does not require the legacy
MiniPro interface GUID. libusb handles the WinUSB device interface when MiniPro
opens it. The UTF-8 path patch preserves Unicode command lines and file paths.

The distribution includes matching source archives, rebuild scripts and
licenses. Windows system WinUSB/SetupAPI DLLs are not redistributed; MSYS or
Cygwin is not required at runtime.

References: [libusb Windows support](https://github.com/libusb/libusb/wiki/Windows),
[Zadig guide](https://github.com/pbatard/libwdi/wiki/Zadig),
[Zadig release history](https://github.com/pbatard/libwdi/blob/master/ChangeLog%20%28Zadig%29).
