# M7 extension and hostile-input measurement workloads

22 November 2026. `HardeningBenchmarks` is a separate development executable;
the historical `ParserBenchmarks` target and its 72 identities stay unchanged.
No library source, public API, dependency pin, specification fixture or existing
performance allowance changes in this step. The preparation checkpoint and
subsequent full scaling baseline are recorded below; neither accepts M7.

## Inputs and cases

`Tools/Sources/BenchmarkCorpus/HardeningWorkload.swift` authors deterministic
raw-byte inputs. Corpus IDs version their shapes. The nominal sizes are
16 KiB, 64 KiB and 256 KiB; complete units can exceed a nominal size, so every
case tags its actual byte count, corpus, profile and syntax-detail selection.

| Corpus ID | Shape | Swift profile |
| --- | --- | --- |
| `m5-composed-v1` | One YAML header; repeated sections with distinct footnotes, inline/display/fenced math, alerts, folded callouts and GFM tables | GFM + all five M5 extensions |
| `footnotes-repeated-v1` | Many references to one definition | GFM + footnotes |
| `open-brackets-v1` | One long unclosed bracket run | Strict CommonMark |
| `long-emphasis-v1` | Unequal long delimiter runs producing deeply nested strong nodes | Strict CommonMark |
| `unmatched-backticks-v1` | Increasing, distinct backtick run lengths | Strict CommonMark |
| `quote-overflow-v1` | Repeated blocks with 256 quote prefixes, exceeding the default 128-container budget | Strict CommonMark |
| `invalid-utf8-v1` | Invalid/truncated UTF-8, NUL and CRLF bytes | Strict CommonMark |

All seven families have Swift parse cases with syntax details off/on at all
three sizes: **42 cases**. The two extension families also have full
parse-plus-render cases off/on: **12 cases**. The five hostile families each
have a C parse control at all three sizes: **15 cases**, giving **69 total**.

Timed iterations include parser creation/validation, parsing and document
destruction. Rendering includes global footnote indexing/backlinks, safe
admonition HTML, omitted metadata and escaped placeholder math; it does not
invoke a TeX engine. Generation and registration perform no parsing/rendering.
List/filter invocations therefore do not secretly parse unselected inputs.

The pinned cmark-gfm receives the identical original byte buffer directly,
with `CMARK_OPT_SOURCEPOS`, including invalid UTF-8 without Swift replacement
decoding. C construction, parsing and freeing are timed. These controls are
informational: C has no matching all-M5 profile; quote-depth and malformed-byte
handling policies need not match. There is no C render comparison here.
Existing mixed-corpus C/absolute/frozen-M2 budgets remain separate and unchanged.

## Functional checks

`HardeningWorkloadTests` verifies actual extension kinds, one shared footnote
with many references, literal unclosed brackets/backticks, many strong nodes,
the nesting-limit diagnostic and replacement output for invalid bytes. At
512 / 4,096 / 16,384 nominal bytes, all seven inputs are deterministic, retain
original bytes, revalidate through the public document initializer, preserve
semantic nodes/diagnostics/output with syntax details off/on, match standard
UTF-16 replacement decoding and reproduce full HTML from reverse-requested
progressive groups. These checks do not establish correctness at every larger
size or prove linear complexity.

## Reproduction and bounds

First build Release development tools with the pinned lockfile. For example,
using task-specific scratch/cache directories on macOS:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/gmsetzer-m7-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/gmsetzer-m7-module-cache \
  swift test --package-path Tools -c release --build-system native --jobs 2 \
  --disable-sandbox --scratch-path /private/tmp/gmsetzer-m7-benchmark-build \
  --cache-path /private/tmp/gmsetzer-m7-benchmark-cache \
  --config-path /private/tmp/gmsetzer-m7-config \
  --security-path /private/tmp/gmsetzer-m7-security \
  --skip-update --force-resolved-versions -debug-info-format none
```

Set the paths to those existing Release executables for the host. Invoke the
Python driver directly, with a fresh output directory for each invocation:

```sh
python3 -I Tools/run_hardening_benchmarks.py \
  --tool /private/tmp/gmsetzer-m7-benchmark-build/arm64-apple-macosx/release/BenchmarkTool \
  --binary /private/tmp/gmsetzer-m7-benchmark-build/arm64-apple-macosx/release/HardeningBenchmarks \
  --output /private/tmp/gmsetzer-hardening-list --list
```

Use `--smoke` instead of `--list` for the five selected 16 KiB cases; it takes
about 26 seconds on the recorded Mac. Use `--run-all` only after owner
confirmation for the full series (allow roughly 6–10 minutes). Linux paths
depend on the existing native host's Swift target/build directory; use no
replacement environment without its required approval.

The driver invokes the built tool directly, without an active SwiftPM/build
parent. Each case gets a private process group, five-second sampling limit
and default **30-second whole-command timeout**, including registration and
warmup. A timeout terminates that group and stops the series. It preserves
logs and a failed receipt; it is never a passing result or timing sample.
Missing/ambiguous exports also fail even when the tool exits zero. The pinned
tool filters base names but exports tagged names; both identities are checked.

Receipts retain compiler/host/load, Git revision and working-tree status,
source/lockfile/executable/allocator hashes, case names, raw-log hashes and
p50 metrics with their displayed units. Source/executable hashes must remain
unchanged throughout a successful invocation. Do not compile, profile or edit
measurement sources while timing. The reported malloc counts and volume are
gross requests, not retained heap or peak RSS; scaled allocation displays are
rounded and must retain their unit labels.

## Recorded checkpoint and remaining work

The [preparation report](Validation/M7/hardening-preparation-2026-11-22.md)
records **10 Release development-tool tests / 5 suites**, **36 isolated Python
tests in each of normal/optimized mode**, **69 listed identities** and **5/5
smoke cases** on macOS arm64 / Swift 6.4.2. The old 72-name list matches the
recorded historical list exactly. The initial failed filter attempt is retained
alongside the corrected run and contributes no timings.

The owner-authorised [full scaling baseline](Validation/M7/hardening-scaling-2026-11-22.md)
then completes **69/69 cases in 326 seconds** at clean `2f5f1bd`, with all
50 measurement-source hashes and existing executable/allocator identities
unchanged. Across 16/64/256 KiB, Swift timing grows about proportionally or
less, but allocation volume and optional token costs warrant further work.
At 256 KiB, long-emphasis syntax collection costs 6.41× the off case, and
open brackets request about 174 M gross bytes. Invalid UTF-8 takes 3.33× the
C control's time; C does not enable its UTF-8 validation flag, so this is not
an equivalent-work parity result. Retained tables cover all 23 size series,
27 annotation pairs and 15 informational C comparisons.

New-harness Linux/minimum Swift 6.2 validation remains pending. Historical
library correctness and parser optimizations retain their original identities;
no repeat of the 245-test library suite, full 72-case series or fresh M6
resource matrix is claimed by this tools-only step. Next profile token
allocation, large item/bracket buffers and malformed-byte processing. Larger
inputs, isolated fuzzing/sanitizers, retained/peak-memory work and M7 acceptance
remain separate.
