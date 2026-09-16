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
