# M7 inline-input, decoding and reference-label follow-up

22 November 2026, development identity `0.7.0-dev.1`, based on PR #28's
`e75567c`. The owner requested three bounded parser changes and a fresh native
x64 comparison. PR #28 merged at `ce5dedc`; the separate
[PR #29](https://github.com/kerker00/GMSetzer/pull/29) now targets main. This is
not merged/released work or
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
An untimed adapter preflight identifies MD4C's omitted formatting newline before
a nested list in a tight item. The verifier normalizes that block boundary
explicitly, with a regression preserving spaces between inline children. It
does not rewrite parser output or discard differences in inline/pre text.

## Completion

Corrected candidate B matches runtime/test commit `f2e0a0e`; `7bb4560` changes
the optional output verifier/test/docs only. Mac and native x64 Debug/Release
each pass **256 tests / 30 suites**, plus **12 Release tool tests / 6 suites**
per host. Mac ASan passes all 256 tests and the 1,024-input / 8,192-parse bounded
mutation probe. Source/tree/token invariants, protected 652 CommonMark / 672
GFM examples, full/grouped HTML and the retained-capacity regression remain
covered. The mutation probe is not coverage-guided fuzzing.

The [minimum Swift CI](https://github.com/kerker00/GMSetzer/actions/runs/45048152056)
passes at `f2e0a0e` on macOS Swift 6.2.3 / Linux Swift 6.2 (256 Swift / 42 Python
tests per host, optimized builds). The
[verifier follow-up CI](https://github.com/kerker00/GMSetzer/actions/runs/45049335473)
passes at `7bb4560` with the additional formatting regression (43 Python tests).
The native normal/optimized Python suites pass all 43 checks separately.

Both hosts complete the unchanged 72-case target; all six C/absolute checks
pass on each host, and all nine frozen M2 Mac checks pass. Separate allocation
profiles (six before / seven B iterations) record **56,618 → 45,670 requests
(−19.34%)**, **56,066,214 → 54,821,926 gross bytes (−2.22%)** per 1 MB CommonMark
parse. `InlineInput` requests fall **10,950 → 2**. These are allocation traffic,
not live/peak memory; instrumented timing is excluded.

| Ordinary p50, 1 MB mixed-v1 | Before ms | B ms |
| --- | ---: | ---: |
| M2 CommonMark | 23.380 | 23.134 |
| M2 GFM | 27.312 | 26.903 |
| x64 CommonMark | 41.583 | 40.010 |
| x64 GFM | 50.528 | 50.135 |

CPU-time gains on mixed input remain small and control-sensitive. Full x64
1 MB C CommonMark rises 24.66% while GFM is unchanged; do not treat the improved
same-run C ratio as an equally large code gain. Mac controls rise 1.60%/7.82%.
Two initial Mac footnote parse rows rise about 14%; a retained 13-case repeat
does not reproduce that regression, but its C controls also improve about 5%.
The repeat's mixed parse reductions are 2.67%/7.55% and footnote parse reductions
6.56%/8.15%; these do not establish a universal pipeline speedup.

In the full x64 reference corpus, syntax-off times fall 7.54–16.30% across
sizes, syntax-on 6.74–13.17%; controls/countermeasurements retain their own
scope. Annotation-off/on costs remain separate.

A reverse-order nine-case x64 repeat confirms reference improvements at 1 MB:
**35.389 → 32.244 ms (off, −8.89%)** and **42.238 → 39.518 ms (on, −6.44%)**.
Its C reference control changes +0.63%, GFM C +0.71%, swift-markdown +0.56%,
and unchanged rendering −0.07%. Mixed CommonMark/GFM change −3.63%/−0.91%.
The C CommonMark anomaly persists (+21.05%) even with reversed variant order;
its input and allocation counts are unchanged. Its cause is not diagnosed and
must not be credited to the Swift optimization or dismissed as general host
drift. Both full pairs and focused controls remain retained.

All **69 hardening / 36 UTF-8** rows complete at unchanged configurations.
The ordinary hardening metadata runner initially fails because the transferred
source has no `.git`; the retained direct driver runs the identical built target
with source hashes instead. This setup failure is not a parser failure.
Fresh native progressive resources pass **42 cases / 126 unchanged checks**,
with all **43 runtime / 5 tool hashes** and **756 raw records** verified on
PowerG5, locally and again from the retained archive. Runtime/test bytes remain
identical to `f2e0a0e`; the measured native packet separately records the two
Python verifier/test changes after initial native compilation.

## Native additional-parser results

All **24 cases / 192 timed batch samples** and **12 output comparisons** pass.
Swift 6.4.2, GCC 16.2.1 (`-O3`), Rust 1.100.0 (Release, LTO, one codegen unit),
native x86_64. Crate VCS metadata matches the pinned release commit; both
foreign executable hashes match the source-pinned build receipt. No system
installation or new execution environment is used.

P50 milliseconds at **1,000,100 input bytes**, CommonMark:

| Parser | Parse result/service | Parse ms | Parse + HTML ms |
| --- | --- | ---: | ---: |
| GMSetzer B | Validated AST, original bytes and source positions | 38.939 | 60.632 |
| cmark-gfm core | C AST with source positions | 20.954 | 25.094 |
| MD4C 0.6.0 | Consumed callbacks; no retained AST | 5.249 | 7.031 |
| pulldown-cmark 0.13.6 | Consumed offset-bearing events; no retained AST | 7.697 | 8.989 |

These purpose-built batch timers do not use package-benchmark's allocation
interposer; do not combine their rows with its 72-case timing series. Their
GMSetzer/core-C parse ratios are **1.97 / 1.86 / 1.68×** at 100 KB / 1 MB /
5 MB. Full HTML remains **2.42× C time at 1 MB**, and **8.62× MD4C / 6.75×
pulldown time**. The same generated output does not remove the cost of the
intermediate AST, source services and validation. These results establish a
remaining throughput gap; event consumption must not be described as equivalent
tree construction. No general C parity is established.

The existing 1 MB swift-markdown comparison is **140.771 ms** in the focused
package-benchmark repeat versus **40.010 ms** for GMSetzer CommonMark. It retains
its fixed GFM/smart-punctuation/Swift-tree differences and a different timing
framework from the table above. It has no measured HTML row here.

The [evidence directory](../../BenchmarkData/m7-inline-input-2026-11-22/)
retains the rejected A preparation, all successful B checks, raw generated
inputs/outputs, both ordinary pairs/repeats, samples, hashes and unsuccessful
setup attempts. This completes the requested bounded optimization/comparison;
owner merge, explicit M7 acceptance and release publication remain separate.
