# Optional native parser comparison

This development-only comparison adds MD4C (C, MIT) and pulldown-cmark (Rust,
MIT) beside GMSetzer and the existing pinned cmark-gfm. No external parser is
added to the library or its root package. `sources.json` pins the MD4C source
revision/file hashes and pulldown release identity; `pulldown/Cargo.lock` pins
the Rust registry packages and checksums. Upstream code is built in a separate
task directory, not vendored into the library.

The comparison deliberately uses **CommonMark without optional extensions**.
The Swift adapter writes the original `BenchmarkCorpus.Corpus.document` inputs
at nominal 100 KB / 1 MB / 5 MB sizes. Exact byte sizes and SHA-256 values are
recorded. Existing GFM and swift-markdown measurements remain in the separate
72-case `ParserBenchmarks` target; its pinned features/options are unchanged.

## Scope

- GMSetzer constructs/validates a source-positioned AST; cmark enables
  `CMARK_OPT_SOURCEPOS` and frees its AST inside each iteration.
- MD4C consumes callbacks without constructing a retained AST. pulldown-cmark
  fully consumes offset-bearing events, including their destruction. These
  are useful context, not equivalent-work tree/parser or C-parity references.
- `html` includes fresh parsing, output allocation, rendering and destruction.
  GMSetzer uses its conformance renderer; raw HTML/unsafe URL behavior is for
  this controlled comparison only. It does not change safe library defaults.
- Before timing, all four generated HTML outputs must match in structure,
  attributes and text. Verification ignores structural indentation and void
  tag spelling only; inline/preformatted whitespace and exact Unicode spelling
  remain significant. Raw outputs/digests are retained. This comparison covers
  these inputs, not general conformance or all-input equivalence.
  Structural formatting includes a newline before a nested block list in a
  tight list item; spaces between inline children remain significant.
- Each adapter loads its input and performs three warmups before its internal
  timer. The timed loop includes parser creation/destruction. Startup, input
  file I/O, corpus generation and verification are excluded. MD4C's input
  buffer and Rust's input String are resident; GMSetzer's public String entry
  still creates its original-byte array per parse.
- Each of 24 cases has eight batch samples. Calibration targets 200 ms per
  batch. Two complete cyclic rotations balance parser order. Programs run
  sequentially, with no own build/test/profiler competing on that host.
  No allocation or peak-RSS claim follows from these timing rows.

## Prepare and run

Use existing native compilers. Installing toolchains, using another execution
environment or running full benchmarks still follows the owner's authorization.
Keep builds/downloads outside timed runs and preserve unsuccessful attempts.

Build `ParserComparisonProbe` in Release from `Tools`, using the same pinned
dependencies as the regular benchmarks. Compile the original `md4c-probe.c`
adapter with `md4c.c`, `md4c-html.c`, `entity.c` and their headers at the exact
revision in `sources.json`; verify every source hash first. Keep the upstream
MIT license with those temporary sources. Compile with `cc -O3 -std=c11`.

Build the original Rust adapter using its committed lockfile:

```sh
cargo build --release --locked --manifest-path Tools/ParserComparison/pulldown/Cargo.toml \
  --target-dir "$COMPARISON_BUILD/rust"
```

Use a task-local Cargo cache when needed; do not install executables globally.
The validation report retains exact compiler versions, commands, dependency
licenses, source hashes, executable hashes and the build receipt. Pass that
receipt to the runner:

```sh
python3 Tools/ParserComparison/run.py \
  --swift-probe "$SWIFT_PROBE" --md4c-probe "$MD4C_PROBE" \
  --pulldown-probe "$PULLDOWN_PROBE" --external-receipt "$BUILD_RECEIPT" \
  --output "$COMPARISON_OUTPUT" --run-all
```

Without `--run-all`, the runner performs output verification only. All three
adapters share `parser parse|html|emit file commonmark iterations`; their
positive integer metrics and iteration counts are checked before use. The
runner verifies source/executable stability after successful runs. Malformed
UTF-8, GFM-like profiles, sanitization and source-map service parity require
separate workloads/contracts.
