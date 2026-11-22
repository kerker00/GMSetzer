# M7 inline-input, decoding and reference-label follow-up

22 November 2026, development identity `0.7.0-dev.1`, based on PR #28's
`e75567c`. The owner requested three bounded parser changes and a fresh native
x64 comparison. PR #28 is a prerequisite; this is not merged/released work or
an accepted 0.7 release. Public API, grammar, Unicode repair/folding, source
positions, tokens, limits and existing comparison budgets remain unchanged.

## Runtime changes and review correction

Three runtime files change:

- `InlineInput` reuses byte/projection capacity within one parse when no custom
  inline callback can retain its buffers. The controller releases its second
  byte-array owner before refill; emission reads the controller's projection
  directly instead of holding a second local snapshot across leaves.
- Custom-inline-rule documents keep fresh per-leaf projections. This is
  deliberate: callbacks can retain immutable contexts. Clearing a shared array
  while retaining capacity could otherwise give each later tiny retained
  snapshot the capacity of the largest earlier leaf. COW preserves values but
  does not itself prevent this capacity amplification. There is no new public
  borrowing promise or mutable cache.
- Decoding consumes an `ArraySlice` directly, respecting its nonzero start/end
  indices. Arrays borrow their full slice; special input no longer materializes
  a second input array. Escapes/entities remain single-pass, and NUL/invalid
  UTF-8 retain the established replacement policy.
- ASCII reference labels normalize directly into `ReferenceLabel` bytes,
  folding A–Z and collapsing only TAB/LF/CR/space. Unicode keeps the original
  full-fold table and exact-byte identity, without canonical normalization.

The initial candidate A reused projections with custom callbacks too. A
retained-context capacity regression test exposes 992 bytes of capacity in a
six-byte later snapshot. This candidate is rejected; its timings/profiles,
failed test and intentionally stopped x64 run remain preparation evidence.
The same capacity regression passes against the original `e75567c` runtime.
Candidate B limits reuse as described above. Candidate A's timing/ASan results
must not be presented as validation of B. The new regression checks source,
bytes, original-range projection and retained capacity across CRLF, quoted
Unicode text, a short paragraph and a list leaf.

## Measurement contract

The before executables are frozen from PR #28's measured renderer state and
verified against its retained source/binary receipts. Native x64 runs on the
existing PowerG5 with Swift 6.4.2. Native source/build directories are isolated;
existing caches are reused, with no system/toolchain installation or VM.
Ordinary timing is separated from builds, tests and allocation profiles on
each host. Source/binary identities and unsuccessful setup attempts are retained.

The original 72-case ParserBenchmarks target retains matching CommonMark/GFM
C controls with source positions, swift-markdown's contextual default-feature
comparison, annotation/reference workloads and optional editor services. The
existing 69-case hardening and 36-case explicit UTF-8 targets retain their
profiles/options/corpora. Progressive resource checks use the unchanged 42-case
matrix and complete runtime/tool source inventory. These checks have distinct
scopes; faster cases never compensate for another failed gate.

The first complete x64 before run executes successfully, but the temporary
export reader rejects legitimate zero-allocation ancillary metrics. Corrected
postprocessing recovers all 72 original rows, verifies unchanged source/binary
hashes and retains the original export/error/reader. Timings are not rerun or
edited to conceal this setup failure.

## Additional open-source comparisons

The optional [comparison adapters](../../../Tools/ParserComparison/README.md)
add [MD4C v0.6.0](https://github.com/mity/md4c/tree/7fc1815a5eeba2af7d6120a76202bf59f3b6e6e4)
and [pulldown-cmark v0.13.6](https://github.com/pulldown-cmark/pulldown-cmark/tree/014b61d38d235f382935bb676bab872b7680afa2),
both MIT. MD4C files are source-hash pinned; Cargo.lock pins Rust artifacts and
the crate's VCS identity is verified against the release commit. Compiled
dependency licenses are MIT or offer MIT/Apache-2.0. Foreign sources/executables
stay outside the library; only original adapters/configuration are added.

This second harness uses the exact same valid-UTF-8 mixed-v1 corpus for four
parsers at three sizes, with CommonMark extensions disabled. Parse-only rows
explicitly distinguish validated/source-positioned AST construction from
consumed callbacks/offset events; MD4C also delegates entity interpretation to
callbacks. They are not equivalent-work C-parity gates. HTML rows include fresh
parsing, output allocation and destruction. All four outputs must first match
in structure, attributes and text, ignoring only structural indentation and
void-tag spelling. Eight rotated batch samples balance parser order. Process
startup/input I/O are excluded. Raw outputs, inputs, samples, commands and
digests are retained; no allocation/RSS conclusion follows from this harness.

An initial Rust preparation uses a `std` feature absent from this release;
after inspecting its pinned Cargo.toml, the adapter selects its actual `html`
feature. The failed resolution is retained, with no version/toolchain upgrade.

## Completion

Corrected-candidate measurements, resource checks, ASan and minimum Swift 6.2 CI
are pending. Initial candidate A has 256-test Mac/x64 Debug/Release passes,
12 Release tool tests per host and Mac ASan/mutation evidence, but its new
capacity regression fails. No completed-performance or accepted-M7 claim is
made for candidate B until its own checks finish.
