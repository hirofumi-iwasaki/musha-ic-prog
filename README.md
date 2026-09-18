# Mushagaeshi IC Programmer

**English** | [日本語](README.ja.md)

A desktop EPROM and memory IC programmer with a read-only hexadecimal viewer and comparison tools.

Repository: [hirofumi-iwasaki/musha-ic-prog](https://github.com/hirofumi-iwasaki/musha-ic-prog)

Version 0.2.0 extends the TL866CS application to five native targets: macOS ARM64, Windows x64/ARM64 and Ubuntu x64/ARM64. The ports are being validated; CI compilation and physical USB acceptance are tracked separately. The Dart / Flutter architecture allows additional programmer backends, such as the XGecu T56, across all supported operating systems. The viewer follows the presentation approach of [Mushagaeshi Binary Editor](https://github.com/hirofumi-iwasaki/musha-bin-editor).

## v0.3.0 release status

[v0.3.0](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.3.0) adds automatic Japanese/English UI selection, a persistent manual language selector, and keyboard navigation in vendor and device menus. Open BIN is now beside the byte-width controls above the input pane; each pane has its own address-jump button. Disconnected warnings are consolidated in the bottom status bar, with errors highlighted in red. Programmer operations and USB transport remain unchanged.

## v0.2.1 release status

[v0.2.1](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.2.1) adds a complete Japanese README with language navigation and expands Windows installation instructions, including the ARM64 signature workaround and normal-restart confirmation. Windows packages include both READMEs beside the executable, and connection messages point to the main README. Matching source bundles on all five targets include the Japanese README. Programmer operations and the corrected v0.2.0 USB transport are unchanged.

## v0.2.0 release status

The republished [v0.2.0 Release](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.2.0) includes the corrected Windows TL866CS transport: bundled libusb with Microsoft's WinUSB driver. Windows requires a one-time driver assignment; Ubuntu may require USB access rules. Replace any archive downloaded before this correction.

All five corrected targets and both Ubuntu 24.04 launch checks passed [automated validation](https://github.com/hirofumi-iwasaki/musha-ic-prog/actions/runs/35074949228). Automated builds do not establish physical USB acceptance. See the [implementation record](.chatgpt/IMPLEMENTATION_0.2.0.md) and [Windows installation instructions](#windows-installation). No new device families or physical SRAM/logic tests are enabled by this port.

## v0.1.0 release evidence

The macOS GitHub Actions build, static analysis, tests and release asset upload have passed. Local validation also covered the packaged application's signature and distribution checksums. The approved castle-and-EPROM artwork is included in the macOS application icon.

A user reported successfully reading a 27C512 using a connected TL866CS. This is a device-specific report, not validation of every catalog entry or operation. Eligible DIP memory devices are available for evaluation; logic IC tests and TL866CS SRAM pin control are not implemented in the app.

## Requirements

- macOS 15 or later; Apple Silicon (M1 or later)
- Windows 11 x64 or ARM64, or Ubuntu 22.04 / 24.04 LTS x64 or ARM64 for the new ports
- TL866CS connected over USB for IC operations
- No Flutter, Homebrew, minipro or libusb installation is needed to run the packaged app

Development uses Flutter 3.47.4, Dart 3.13.3 and Xcode. Hardware connection was checked on macOS 27.0 (26A428), with TL866CS firmware 03.2.86 (0x256). macOS 15 / 26 GUI and hardware acceptance remain separate from CI compilation.

## UI language support

Version 0.3.0 adds an application UI language control. **Language / 言語** offers the persistent choices **System / システム**, **English**, and **日本語**; a manual choice updates the application interface immediately and is retained for the next launch. It does not change programmer state, selected data, or an operation in progress.

System mode uses only the first OS-preferred language: Japanese is selected when that language is Japanese (including a Japanese regional variant); every other primary language uses English. A Japanese language listed after another preferred language does not select Japanese. On Windows and Linux, restart the application after changing the OS display or session language to ensure the new System-mode language is picked up. The native file picker remains OS-owned: app-supplied labels can be localized, but its chrome may continue using the OS language after an in-app override.

UI changes were manually checked on macOS. These changes do not establish new hardware validation.

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

## Windows installation

### Download and extract

1. Download [v0.3.0](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.3.0):
   - Intel/AMD Windows PCs: `musha-ic-prog-windows-x64.zip`.
   - Windows ARM PCs and Windows in Parallels on Apple Silicon: `musha-ic-prog-windows-arm64.zip`.
2. Extract the entire archive before running the app. Keep `mushagaeshi_ic_programmer.exe`, its DLLs, `data/`, `native/` and `resources/` together. In particular, keep `native/libusb-1.0.dll` beside `native/minipro.exe`.
3. Open `mushagaeshi_ic_programmer.exe`. Flutter, MiniPro and libusb do not need separate installation. File viewing works without a programmer; USB operations require the driver assignment below.

If you downloaded v0.2.0 before its Windows transport correction, replace that archive with the republished version. Driver setup alone cannot fix the earlier executable. Windows packages built from this revision include both English and Japanese READMEs beside the executable; previously published packages may still refer to `resources/minipro/WINDOWS_USB_SETUP.md`. This section supersedes that older guide.

### Connect TL866CS to Windows

Close other programmer software, including the original MiniPro application. Connect one TL866CS over USB.

For Parallels on a Mac, assign **MiniPro TL-866 Programmer** to the Windows virtual machine using Parallels' USB device menu or connection prompt. The programmer must be attached to Windows rather than macOS. After restarting or reconnecting, check this assignment again if the app cannot see the device.

### Assign WinUSB with Zadig

Windows includes the WinUSB driver, but TL866CS may need a one-time assignment to that driver. This installation requires administrator approval; normal use of the app does not.

1. Download [Zadig from its official website](https://zadig.akeo.ie/). Use the current release; ARM64 WinUSB installation support was added in Zadig 2.8. That support does not eliminate the Windows ARM64 signature restriction described below.
2. Start Zadig and approve the administrator prompt.
3. Select **Options > List All Devices**.
4. Select **MiniPro TL-866 Programmer**, or the corresponding TL866CS entry. Verify **USB ID `04D8 E11C`** before proceeding. Do not select a keyboard, mouse, hub or another USB device. TL866A shares this ID; the application separately checks the model and only enables TL866CS operations.
5. Select **WinUSB** in the replacement-driver field, then **Install Driver** or **Replace Driver**. Do not select libusbK or libusb-win32 for this application.
6. Once installation succeeds, disconnect and reconnect TL866CS, open the application and refresh the connection.

Assigning WinUSB may prevent the original MiniPro application from using its legacy vendor driver. To return to that application, restore its driver with the official vendor installer or Device Manager's driver rollback, when available.

### Windows ARM64: installation fails with a signature error

Windows ARM64 can reject Zadig's generated driver package even though WinUSB itself is provided by Microsoft. The user-facing error may be **Operation not supported or not implemented**. That message alone is not sufficient to identify the cause.

In Zadig, enable **Options > Advanced Mode**, select **Options > Log Level > Debug**, and inspect the installation log. The following messages identify the signature rejection encountered with this application:

```text
Driver package signer is not trusted by system, and Code Integrity is enforced.
Driver package failed signature validation. Error = 0xE0000243
This version of Windows is refusing to trust the installed certificate.
```

This is a [known libwdi/Zadig ARM64 issue](https://github.com/pbatard/libwdi/issues/289). It occurs before the application can communicate with the programmer; reinstalling the application does not resolve it.

For this specific error, the following temporary installation workaround succeeded on **Windows 11 ARM 25H2, OS build 26200.9457, in Parallels Desktop on a MacBook Pro M1 Max**:

1. Save your work. If BitLocker or Device Encryption is enabled, have the recovery key available before changing startup settings. If you cannot retrieve the key, stop here.
2. Inside Windows, hold **Shift** while choosing **Restart** from the Start menu. Do not reset or suspend the virtual machine from Parallels instead.
3. Choose **Troubleshoot > Advanced options > Startup Settings > Restart**.
4. On the numbered startup menu, press **7** for **Disable driver signature enforcement**. The number key avoids Mac function-key mapping issues.
5. Once Windows starts, ensure TL866CS is assigned to the Windows guest. Run Zadig and repeat the **`04D8:E11C` > WinUSB** installation above. Do not restart again before completing installation.
6. After installation, restart Windows normally, without selecting option 7. Reconnect TL866CS to the Windows guest and confirm that the application recognizes it. Confirm reading with the correct IC profile and placement before attempting other operations.

**This temporarily weakens driver signature enforcement for that boot session.** Use it only to install the intended WinUSB package from official Zadig. Normal restart restores enforcement. The procedure does not require permanently enabling Test Mode or disabling Secure Boot or memory integrity. If it still fails, retain the log and investigate the specific error instead of disabling additional protections. See [Microsoft's startup settings instructions](https://support.microsoft.com/en-us/windows/experience/startup-boot/windows-startup-settings) and [the temporary signature-enforcement setting](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/test-signing).

### After a normal restart

The user confirmed that the application continued to work after a normal restart in the Parallels environment above. **For that tested installation, option 7 was needed only during initial driver installation, not on every boot.** The installation package's signature check and the loading of Microsoft's WinUSB driver are separate stages.

This report does not guarantee every Windows build or configuration. Reinstalling Windows, removing the driver, restoring an older VM snapshot or changing device/USB assignment may require setup again. If the programmer disappears, first check Parallels USB assignment and the bound driver rather than repeating the signature workaround automatically.

### Windows connection troubleshooting

From PowerShell in the extracted application directory, run:

```powershell
.\native\tl866_probe.exe
```

The probe reads device information without operating the IC.

| Result | What to check |
| --- | --- |
| `count` is `0` | Cable, USB connection and Parallels assignment to Windows. |
| More than one matching device | Disconnect additional TL866A/CS programmers. |
| Empty `driverService` | The driver has not been assigned successfully. Follow the Zadig instructions. |
| `driverService` is not `WinUSB` | A different driver is bound. Check the selected device and driver in Zadig. |
| `driverService` is `WinUSB`, `interfaceReady` is `true` | The driver prerequisite is present. The app must still complete its model/firmware check. Close other programmer software and reconnect if opening fails. |

For a persistent failure, report the Zadig version and error log, Windows version/OS build from `winver`, whether Windows runs on hardware or in a VM, and the probe output. Indicate whether installation was attempted during the temporary option-7 boot. Do not include BitLocker recovery keys or other credentials.

## Ubuntu installation

Download `musha-ic-prog-linux-x64.tar.gz` or `musha-ic-prog-linux-arm64.tar.gz` from [Releases](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.3.0), matching the processor of your Ubuntu system. Extract the complete directory and run `mushagaeshi_ic_programmer` from the extracted bundle.

Install the distribution's GTK 3, EGL/OpenGL and LZMA runtime libraries (`libgtk-3-0`, `libegl1`, `libgles2`, `libgl1-mesa-dri`, `liblzma5`). If USB access is denied, follow the included [USB access instructions](linux/udev/README.md). Do not run the application as root.

A user reported successful Linux hardware operation; the distribution version, architecture and exact operation coverage were not specified. The Windows ARM64 report above and the Linux report are hardware observations, not validation of every target, IC profile or programming operation. The same file viewer and operation confirmation flow is used on every target.

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

## Keyboard selection

Open the vendor selector or the device dropdown arrow, then type an initial to jump to the first matching entry. Repeated presses of the same initial cycle through matching entries and wrap to the first. Typing several characters within 800 ms searches by prefix. Arrow keys and Home/End move the highlight; Enter confirms and Escape cancels. Navigation alone does not change the selected vendor or device. Typing directly in the device text field retains substring search.

## GitHub Actions builds

The **Desktop build and package** workflow runs on pushes to `release/0.3.0`, pull requests, published Releases and manual dispatch. It builds all five targets using native runners and Flutter 3.47.4 pinned to revision `9584c6713b324636289d067944a46fd6b49df14b`. Ubuntu packages are built on 22.04 and also undergo headless launch checks on 24.04.

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
