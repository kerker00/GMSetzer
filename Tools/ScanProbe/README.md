# Native CR/LF scan experiment

This standalone development probe compares six ways to find the next line
boundary. It compiles the **actual** `Sources/SetzerSyntax/ByteSearch.swift`
baseline alongside experimental code; it changes neither library source nor
package manifests and has no package-manager dependencies. Foundation is used
only by this development executable for JSON output.

| Strategy | Access / algorithm |
| --- | --- |
| `buffer-scalar` | One byte at a time through an unsafe buffer |
| `span-scalar` | The same scalar search through a borrowed `Span<UInt8>` |
| `word8-current` | Current production 8-byte mask search |
| `raw-span-word8` | Same 8-byte algorithm using bounded `RawSpan` integer loads |
| `simd16` | 16-byte comparisons, first matching lane, scalar tail |
| `simd32` | 32-byte comparisons, first matching lane, scalar tail |

CRLF is combined into one boundary, matching the parser's recording traversal.
The initial count/reservation pass, line-table allocation, parsing, Unicode
decoding, token collection and HTML output are **outside** this experiment.
The raw-span implementation uses the bounds-checking `fromByteOffset:` load
overloads for integer types. SIMD loads are unaligned and occur only when a
whole vector fits; shorter tails use scalar access.

## Run

From a complete checkout with the existing native Swift compiler:

```sh
python3 -I Tools/ScanProbe/run.py --output /tmp/gmsetzer-scan-release
```

Use a new task-specific output directory. The runner selects Release `-O` and
whole-module optimization, with Swift language mode 6. On macOS it selects the
current SDK and explicitly targets macOS 15. Compilation and execution each
have a 180-second process-group timeout. Missing or malformed output, changed
source/binary hashes and failed correctness checks fail the receipt.

On a Mac with AddressSanitizer support, run separately:

```sh
python3 -I Tools/ScanProbe/run.py \
  --output /tmp/gmsetzer-scan-asan --asan
```

This uses Debug/ASan and verification only; it produces no timing rows. Do not
compile or profile alongside measurements on that host. Existing owner approval
requirements for benchmarks and long tests still apply. Use existing native
Linux hosts; no toolchains, VMs or containers are installed by this runner.

## Checks and sampling

Before timing, all strategies match an independent scalar position-list oracle
on **15,520 views**: lengths 0–96, offsets 0–31, and five families covering no
terminators, dense LF, CRLF, malformed/high bytes and seeded random bytes.
Multiple starting positions and full-scan fingerprints are checked. Nonempty
views end at the allocation boundary, exercising vector tails under ASan.

The **72 rows** are four corpora × 64 KiB/1 MiB/5 MiB × six strategies:
80-byte LF lines, dense CRLF, multibyte text and one long line. Each row has
12 samples, with two complete cyclic rotations of strategy order. Untimed
current-word8 calibration chooses a common iteration count per input for all
strategies. Each sample mutates byte zero according to the same deterministic
sequence, preventing invariant scans from being hoisted out of the timed loop.
Checksums and iteration counts must agree across strategies for every round.
Input generation, oracle checks and result encoding occur outside timing.

The receipt retains compiler/target/flags, host/load, all 43 library/manifest
hashes, four measured source/driver hashes, executable digest and command
results. `probe.stdout` retains all raw samples/checksums; `summary.json`
derives medians, decimal MB/s and time relative to the current word8 traversal.

## Interpretation

These are isolated traversal measurements, **not parser speedups**. Comparing
the two scalar variants and the two word8 variants separates access/view
changes from algorithm width. A wider vector type does not guarantee a faster
implementation or the same generated code across architectures.
Actual compiler execution is recorded; compiling Swift language mode 6 or a
macOS 15 target with Swift 6.4.2 does not prove Swift 6.2 compiler compatibility
or execution on the minimum OS. Production adoption needs those checks and
paired full-parser measurements with unchanged semantic/resource gates.
See the [results report](../../Docs/Validation/M7/scan-evaluation-2026-11-22.md).
