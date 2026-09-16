# Windows native payload

`tool/build_native_windows.ps1 -Architecture x64` and `-Architecture arm64`
build two native helpers: MiniPro's pinned WinUSB backend and a SetupAPI-only
probe.  The probe enumerates the TL866A/CS interface GUID
`85980D83-32B9-4BA1-8FDF-12A711B99CA2`; it does not open the device or issue a
USB transfer.

The helpers are built with LLVM-MinGW 20240619 UCRT, hosted by its x64 Windows
toolchain and cross-targeted to the selected architecture. The shipped EXEs
are checked as x64 or ARM64 and do not require MSYS/Cygwin at runtime. zlib
1.3.2 is built statically for each target; WinUSB and SetupAPI are Windows
system DLLs and are not redistributed.

The Windows MiniPro patch translates UTF-8 command-line file names to UTF-16
only at the CRT file-open/stat boundary. It keeps the upstream WinUSB protocol
backend, including its interface GUID, unchanged.

Before a programmer is usable, Windows must have a signed driver binding that
publishes the required interface GUID. MiniPro's backend expects this binding;
a generic WinUSB/Zadig assignment has not been hardware-validated. The app
does not install or replace drivers and runs without elevation. ARM64 needs an
ARM64-compatible signed binding.
