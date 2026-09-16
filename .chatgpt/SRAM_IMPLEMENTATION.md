# SRAM test engine implementation record

Date: 2026-09-16

The local MiniPro additions live in `third_party/minipro/`, with the upstream
GPL-3.0 license and reference commit
`cae74c0607077d6260b24995f5e4c0d0b66a6a2e`.  The subtree is a tracked overlay,
not a nested Git checkout.  `third_party/minipro/UPSTREAM.toml` records the
pinned base and `tool/materialize_minipro_sram.sh` uses `git archive` to make
an ignored `.tooling/minipro-sram` full source tree with the two engine files
in `src/` and `src/sram_test.o` added to `COMMON_OBJECTS`.  It verifies the
exact commit and contains no remote publication or algorithm download.
Materialization creates a temporary sibling and renames it only to a new,
direct `.tooling/` child.  Existing targets, traversal, repository-root
targets, and a symlinked `.tooling/` directory are refused without deletion.

## Test semantics

`mp_sram_test` is destructive.  For each of `00`, `FF`, `55`, `AA`, address
low byte, each independent address-byte pass through bits 56-63, and a
byte-wide XOR of all address octets, it first writes the *entire* requested region and only then
reads and compares the entire region.  The address passes distinguish higher
address lines (including A8, A16, and higher address bytes) rather than
repeating only `address % 256`.

The caller supplies a bounded scratch buffer and callbacks.  A transfer is
accepted only when its status is `OK` and its completed length exactly equals
the requested length.  Unknown responses and short transfers fail closed.
The report includes pattern, byte address, expected byte, actual byte, and
the callback statuses.  `begin` starts one session for all patterns; after
every attempted begin, `end` runs exactly once even on begin failure,
cancellation, I/O failure, or mismatch.  Adapters must make end safe after a
partial begin failure.

## MiniPro integration status

The upstream source inspection found SRAM dispatch to
`minipro_test_ram_generic` for TL866II+, T48, T56, and T76.  TL866CS uses
`tl866a_logic_ic_test` and has no equivalent SRAM branch.  Its generic
bit-bang block-write path is also unimplemented.  Therefore no TL866CS
hardware adapter, CLI route, or ROM read/write reuse was added.  Adding one
requires an independently verified profile and a callback adapter that
documents exact protocol status, read/write count, power hold, and safe end.

## Local verification

Run the repeatable mock suite without MiniPro's libusb dependency:

```sh
tool/test_sram.sh
```

The mock suite covers a healthy memory, aliases across A15/A16, cancellation,
I/O failure, begin failure cleanup, end failure, unknown status, short
transfer rejection, and a NULL report.
