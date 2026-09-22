# Local MiniPro SRAM test additions

This directory contains local additions intended for a future fork of
[minipro](https://gitlab.com/DavidGriffith/minipro/), based on upstream commit
`cae74c0607077d6260b24995f5e4c0d0b66a6a2e` (0.7.4-era source).

The upstream project is GPL-3.0-or-later.  Its unmodified `LICENSE` is kept
alongside these additions.  The files in `sram/` are also GPL-3.0-or-later;
their headers identify the local change and date.

This is a small overlay, with a reproducible pinned full-fork materialization
rather than a committed second upstream checkout. Run
`tool/fetch_native_sources.sh`, then `tool/materialize_minipro_sram.sh`, to
download and hash-check the exact upstream archive recorded in `UPSTREAM.toml`,
create the ignored `.tooling/minipro-sram/` tree, copy `sram_test.[ch]` into
`src/`, and add `src/sram_test.o` to `COMMON_OBJECTS`. Set `MINIPRO_SOURCE`
only to use an existing upstream Git checkout at the same pinned commit. The
materialized tree has no nested `.git` directory and still has no physical
adapter. The standalone mock test is reproducible without libusb:

For safety, materialization only accepts a nonexistent direct child of the
repository's `.tooling/` directory.  It refuses an existing target, a project
root, traversal, and symlinked tooling directories; choose a fresh output name
or remove a prior generated directory yourself.

```sh
tool/test_sram.sh
```

## Connection safety guard

The materializer also applies `patches/expected-programmer.patch`. It rejects
more than one device across MiniPro's three USB-ID families before opening a
handle. `--connection-json` returns a normal-mode programmer's canonical
model, exact MiniPro firmware string, serial, and `serial:<serial>` identity.
For an IC operation, `--expected-model`, `--expected-identity`, and
`--expected-firmware` must be supplied together. The same opened handle must
be in normal mode and match all three values before a target is selected.
Empty or non-printable serials fail closed. The serial binding is portable;
Windows SetupAPI instance paths cannot safely be equated to a libusb handle.

## Hardware boundary

`sram_test.[ch]` is transport independent.  It holds one callback session
from `begin` through `end`; it never turns ROM program/read commands into an
SRAM adapter.

No adapter is supplied or enabled for TL866CS.  In the inspected upstream
revision, TL866CS uses `tl866a_logic_ic_test`, while SRAM dispatch to
`minipro_test_ram_generic` exists for TL866II+, T48, T56, and T76.  Upstream
`bitbang.c` also has an unimplemented block-write path.  A TL866CS adapter
must therefore remain unavailable until its power hold, pin control, exact
read/write protocol, status semantics, and cleanup behavior are verified on
real hardware.

The engine's callback contract rejects unknown statuses and short transfers.
`end` is called exactly once after every attempted `begin`, including a begin
failure, cancellation, or I/O failure.  An adapter's `end` must consequently
be safe after a partially initialized session.

## v0.4.0 connection guard (2026-09-22)

The local `patches/expected-programmer.patch` is applied to the pinned source
for every desktop target. It adds `--connection-json` for normal-mode model,
firmware and serial discovery, and the all-or-none operation arguments
`--expected-model`, `--expected-identity` and `--expected-firmware`.
Operations verify these values against the opened handle before IC access.
USB enumeration rejects multiple MiniPro-family devices, including shared-ID
models. The application requires this guard and does not fall back to an older
unguarded payload. This extension does not implement a physical SRAM adapter.

The Windows build uses the same libusb transport source (`usb_nix.c`) and
additionally applies the existing UTF-8 path patch. Build manifests record the
safety patch SHA-256. Matching source bundles include the patch and its build
scripts. No manufacturer algorithm data is added.
