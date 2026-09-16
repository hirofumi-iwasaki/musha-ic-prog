# Windows USB setup and native payload

The Windows application uses bundled libusb 1.0.29 and Microsoft's built-in
WinUSB driver to communicate with TL866CS. The first connection may require
assigning WinUSB to the programmer. This setup is separate from installing the
application and requires administrator approval. Normal application use does
not require elevation.

## First-time setup (Windows 11 x64 or ARM64)

1. Connect TL866CS directly to Windows. In a virtual machine, attach the USB
   programmer to the Windows guest, rather than leaving it attached to the host.
2. Close the original MiniPro application and other programmer applications.
3. Download current [Zadig](https://zadig.akeo.ie/) from its official site.
   Zadig 2.8 or newer supports ARM64 WinUSB installation; its installer UI may
   run under Windows x86 emulation. Use the WinUSB option on either architecture.
4. In Zadig, select **Options > List All Devices**. Select the TL866CS and verify
   its **USB ID is `04D8 E11C`**. The displayed device name may vary. Do not select
   a keyboard, hub, or another USB device. This ID is shared with TL866A; the app
   checks the programmer model separately and enables TL866CS operations only.
5. Select **WinUSB** as the replacement driver, then **Install Driver** or
   **Replace Driver**, depending on the current binding. Approve the Windows
   administrator prompt. Do not choose libusbK or libusb-win32.
6. Disconnect and reconnect the programmer, then open Mushagaeshi IC Programmer
   and refresh the connection. Keep all files from the application archive
   together, including `native/libusb-1.0.dll`.

The application does not install drivers automatically. WinUSB assignment may
prevent the original MiniPro application from using its legacy vendor driver.
To return to that application, restore its vendor driver using its official
installer or Device Manager's driver rollback, when available. Signature
verification and Secure Boot do not need to be disabled.

## Troubleshooting

From PowerShell in the extracted application directory, run:

```powershell
.\native\tl866_probe.exe
```

This read-only probe enumerates USB device information without operating the
IC. For a single connected programmer, `driverService` should be `WinUSB` and
`interfaceReady` should be `true`. This indicates the driver prerequisite;
it does not prove that USB communication or IC operations succeeded. A missing
service requires driver setup; another service indicates a different binding.
A zero device count means Windows cannot see the programmer: check the cable
and, for a VM, USB passthrough. Disconnect additional TL866A/CS programmers
before using the app. If WinUSB is selected but opening fails, close other USB
applications, reconnect, and recheck the binding in Zadig.

The former v0.2.0 release used a legacy vendor-driver path for TL866CS and was
withdrawn. Assigning WinUSB does not fix that older executable; use a corrected
build from the republished v0.2.0 Release. Windows physical USB acceptance remains
pending separately for x64 and ARM64.

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
