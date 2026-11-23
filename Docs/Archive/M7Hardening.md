# M7 speed and hardening

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

**Merged candidate, 22 November 2026:** [PR #26](https://github.com/kerker00/GMSetzer/pull/26)
merged at `a273810`, with development identity `0.7.0-dev.1`. The measured
checkpoints below retain their historical source identities and scope. Explicit
M7 acceptance and source-only 0.7 publication remain separate.

21 November 2026, initial work on `feature/m7-hardening`, based on the
accepted M6 runtime (`a8a0351`) and documentation follow-up `0cf6690`.
Development identity is now `0.7.0-dev.1`, separating M7 from the accepted
M6 implementation published as 0.6.0. Evidence through `61c3667` used
`0.6.0-dev.1`; those original receipts/hashes are retained. The version-only
follow-up does not claim a new timing/resource series. The initial preparation through
`9e7bc71` changes tests/documentation only. The measured optimization below
reuses scratch buffers and changes two runtime files; public API, dependencies
and protected specification fixtures remain unchanged. M7 is not accepted or
merged yet.

The version-only follow-up passes the complete **245-test / 29-suite macOS
Debug run** with Swift 6.4.2. All parser/rendering implementation files match
`61c3667`; the only runtime difference is `GMSetzerVersion.current` changing
from `0.6.0-dev.1` to `0.7.0-dev.1`. No new benchmark series or Linux/minimum-
compiler run is claimed for this metadata change. The separate 0.6.0 release
was published at `8ff2061` after [PR #25](https://github.com/kerker00/GMSetzer/pull/25)
merged; its source notes and validation are now integrated here.

## Bounded mutation regression coverage

`HardeningTests` adds three Swift Testing tests. Eight fixed PRNG seeds produce
32 samples each, used with four parser configurations: strict CommonMark,
GFM, CommonMark + all M5 extensions and GFM + all M5 extensions. These are
**1,024 profile/input combinations**, not 1,024 distinct randomly discovered
failures. Container budgets rotate through 1, 4 and 16 levels.

The authored seed document exercises all five M5 extensions, forward links,
repeated/cyclic footnotes, parsed titles, GFM tables/task lists/strikethrough,
headings, opaque math, code, raw HTML, unsafe URLs and trailing whitespace.
A dedicated check verifies that selected extension kinds are actually present
before mutation. Mutations include truncation, deletion, raw-byte insertion/
replacement, incomplete/invalid UTF-8, BOM/NUL/CRLF/tabs, long dollar runs and
container prefixes. Inputs are capped at 1,024 bytes. A further **24 depth
cases** cover excessive quotes and nested alerts/callouts across the four
profiles and three budgets.

For every profile/input pair, the tests check:

- Exact original bytes; annotation on/off equality of nodes, diagnostics,
  custom fallbacks, rendering policy and full output. Built-in extensions must
  not produce rejected-extension-result diagnostics on malformed source.
- Revalidation through the public `Document` initializer, including source
  segments, tree topology, tokens and ownership.
- UTF-16 length against standard-library replacement decoding; addressable
  UTF-8/UTF-16/line-column round trips; root conversion, parent/caret queries
  and outline ranges against the same snapshot.
- All native rules, finding/fix validation against original bytes, and
  reparsing up to three independently applied advisory fixes per input.
- Exact full/grouped HTML equality, using original anchors, global extension
  context and reverse group requests at soft budgets 1/64/32,768 bytes.

Failures identify the numeric seed, sample, profile and depth. Reproduce the
input from the generator at the recorded commit; it has no system entropy,
filesystem, process-hash or clock input. The input source, PRNG and mutations
are authored here and require no third-party corpus licence.

These are bounded consistency/robustness checks. Existing protected specification
tests retain the external expected-HTML oracle. This is not coverage-guided
fuzzing, a process-isolated crash/hang campaign, a complete malformed-input proof
or evidence of linear complexity at larger sizes. No timing threshold is added
to ordinary tests.

## Executed validation

macOS arm64, Xcode 27.2 / Apple Swift 6.4.2, and the native Linux follow-ups:

- Complete Debug suite: **245 tests in 29 suites pass**, including all eight
  mutation cases and all 652 CommonMark / 672 GFM protected examples.
- Complete Release suite: the same **245 tests pass**.
- At initial preparation, the M6 offline evidence checker matches all 43
  runtime/manifest files and passes 42/42 historical cases. The subsequent
  optimization changes two runtime files, so that historical receipt no longer
  matches the candidate. It is not reused as fresh resource evidence.
- Native Linux ARM64 on an existing Raspberry Pi 5 / Debian 13.7 / Swift
  6.4.2: all **245 tests / 29 suites pass in Debug and Release**, plus all
  **31 Python tests** in both isolated normal and optimized modes. The
  [Linux report](../Validation/M7/linux-arm64-2026-11-21.md) retains receipts/logs.
- Native Linux x64 on an existing Intel i5-6600K / CachyOS / Swift 6.4.2:
  **245 library tests / 29 suites** and **6 development-tool tests / 4 suites**
  pass in both Debug and Release; all **31 Python tests** pass in both modes.
  This includes direct generated-document C comparisons; see the
  [x64 report](../Validation/M7/linux-x64-2026-11-21.md).
- Minimum Swift 6.2 execution of the three new tests remains for PR CI. Their
  M6 predecessor has merged-main CI on both hosts; that is not substituted
  for running the new tests on the minimum compiler.

Commands use the native SwiftPM build system, `--disable-sandbox`, isolated
scratch/cache/configuration/security/module directories under `/private/tmp`
on macOS and a task-specific `/tmp` directory on Linux, and `-c release`
for the optimized suite. The focused reproducer is:

```sh
swift test --filter HardeningTests
```

No parser/rendering defect was found in this bounded campaign, and no runtime
workaround or optimization was introduced. Source grammar and baseline IDs
were not changed to accommodate generated inputs.

## First complete performance baseline

The existing `ParserBenchmarks` target builds successfully with the pinned
`Tools/Package.resolved`. A list-only invocation enumerates **72 unique cases**
(24 at each of 100 KB, 1 MB and 5 MB). The exact
[case list](../Validation/M7/benchmark-cases.txt) and
[preparation identity](../Validation/M7/preparation.json) are recorded. Build/list
does not execute benchmark samples. Development dependency objects were copied
from the existing local cache into task-specific storage; the original checkout
and its local changes were not used as the source under test.

The owner approved the complete series on 21 November 2026. It ran at clean
commit `1edf1a4`; all 72 cases complete and all four existing budget commands
pass. See the [measurement report](../Validation/M7/baseline-2026-11-21.md) for
exact values, controls, allocation observations and the archived raw streams.
The preparation record above remains the historical build/list checkpoint.

The executed command, from the repository root:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/gmsetzer-m7-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/gmsetzer-m7-module-cache \
  swift package --package-path Tools --build-system native \
  --scratch-path /private/tmp/gmsetzer-m7-benchmark-build \
  --cache-path /private/tmp/gmsetzer-m7-benchmark-cache \
  --config-path /private/tmp/gmsetzer-m7-benchmark-config \
  --security-path /private/tmp/gmsetzer-m7-benchmark-security \
  --disable-sandbox --skip-update --force-resolved-versions \
  -debug-info-format none \
  benchmark run --target ParserBenchmarks --format markdown \
  --time-units microseconds --no-progress \
  > /private/tmp/gmsetzer-m7-baseline.md \
  2> /private/tmp/gmsetzer-m7-baseline-build.log
```

This is the verified list/build command with `list` replaced by `run` and the
Markdown/unit options added. Release optimization remains enabled. Existing
per-case sampling lasts at most five seconds, plus warmup/setup; allow roughly
6–12 minutes for the complete series on this Mac. Record a clean commit,
compiler/host/allocator, actual tagged inputs, raw output and source hashes;
keep competing workloads/power conditions consistent before measurement.

Evaluate the corresponding CommonMark/GFM/C cases and frozen M2 allowances:

```sh
python3 -I Scripts/check_benchmark_budget.py /private/tmp/gmsetzer-m7-baseline.md
for gmsetzer_variant in core selected-registry selected-inline; do
  python3 -I Scripts/check_m2_budget.py /private/tmp/gmsetzer-m7-baseline.md \
    --baseline Docs/Validation/M1Acceptance/m2-baseline.md \
    --allowance Docs/Validation/M1Acceptance/inline-budget.json \
    --variant "$gmsetzer_variant"
done
```

Preserve limits and repeat suspect measurements before changing implementation
or attribution.
The current suite includes registry/inline dispatch and optional editor services;
further real-M5 and hostile-input scaling/resource cases remain M7 work.

A subsequent owner-authorised native Linux ARM64 series at `c299783` completes
all **72 cases** with matching runtime/tool hashes. All six same-host parser/C
ratios satisfy ≤2× C. High reported load and small large-input sample counts
limit conclusions; Mac absolute deadlines and frozen M2 controls are not
applied to the Pi. See the [Linux report](../Validation/M7/linux-arm64-2026-11-21.md)
for commands, allocation data, sanitized logs and measurement limits. No
installation or replacement execution environment was needed.

The subsequent [x64 series](../Validation/M7/linux-x64-2026-11-21.md) completes
72/72 cases using the same built Release benchmark tool directly. A SwiftPM
parent consumed about 2.52 CPU cores during an interrupted preliminary run;
the direct series removes that competing caller and averages 26.19% total
host CPU busy time on four cores. Use its documented direct invocation for
future native Linux measurements. Earlier wrapped Mac/Pi series retain their
recorded conditions; the x64 observation does not quantify their interference.
All six direct x64 C ratios pass: GFM is within about 7% of C; CommonMark is
33–62% slower. Parity remains the aim, so CommonMark is the next parser
profiling priority. No runtime optimization is claimed by changing the driver.

## First measured optimization

The [inline scratch-buffer report](../Validation/M7/inline-scratch-2026-11-21.md)
records CPU/allocation profiles and a two-file change that reuses child-index
and emission-event buffers within each inline parse. Per 1 MB CommonMark parse,
allocation recording observes **109,538 → 56,618 requests (48.31% fewer)**.
Four separate direct 18-case subsets compare old/new binaries on each host.
CommonMark time improves **15–17% on M2 / 6–7% on x64**; GFM and selected no-op
registry/inline cases also improve. Matching C controls vary by at most 2.07%
on M2 / 1.36% on x64. All six current C/absolute Mac gates and nine frozen M2
checks pass unchanged; all six x64 relative C checks pass. No cross-host
speedup or peak-memory reduction is inferred.

The candidate passes 245 library tests / 29 suites in Debug and Release and
6 Release development-tool tests / 4 suites on both macOS and Linux x64.
Candidate Linux ARM64 and minimum Swift 6.2 execution remain pending. Current
progressive correctness tests pass, but the historical M6 42-case resource
receipt is not hash-matched to these runtime changes; fresh resource evidence
remains required. The full 72-case suite was not repeated for this small step.

CommonMark is still 24–54% slower than C on x64 in the new series. Continue
profiling remaining traversal, document construction/validation and trigger
scanning toward parity, plus HTML emission and real-M5/hostile-input scaling/
resource work; then broaden the isolated fuzz/sanitizer campaign. The initial
Mac baseline remains historical; the new targeted Mac series supplies fresh
C/absolute/frozen-M2 checks for this candidate.

Full benchmark and long-test/fuzz execution retain the owner-confirmation gate
in `CLAUDE.md`. M7 completion requires both the existing speed budgets and
documented robustness/allocation evidence; a passing small campaign alone does
not complete it. The measurement result is recorded locally; push, PR and release remain
separate steps.

## Extension and hostile-input measurement preparation

22 November 2026: the separate
[69-case workload matrix](M7HardeningWorkloads.md) is implemented and listed.
Seven deterministic input families cover composed M5, repeated shared
footnotes, unclosed brackets, long emphasis, unmatched backticks, quote-budget
overflow and invalid UTF-8 at 16/64/256 KiB. Syntax collection off/on and
composed parse-plus-render cases are explicit; C controls use identical raw
bytes but remain informational where policies differ. No library code or
existing 72-case workload/budget changes in this preparation step.

The [checkpoint report](../Validation/M7/hardening-preparation-2026-11-22.md)
records 10 Release tool tests / 5 suites, 36 Python tests in both isolated
modes and five successful short Mac measurements with source hashes unchanged.
The bounded direct driver stops on timeout or invalid exports and retains
failed attempts. Full size scaling, new-harness Linux/Swift 6.2 validation and
the previously pending resource/fuzz evidence still need execution. This
checkpoint does not accept M7 or establish larger-input complexity.

## Full extension/hostile-input scaling baseline

The owner-authorised [full series](../Validation/M7/hardening-scaling-2026-11-22.md)
then completes **69/69 cases**, exit 0, at clean `2f5f1bd` on macOS arm64 /
Swift 6.4.2, in **326 seconds**. All 50 measurement-source hashes and existing
Release executable/allocator identities match before/after. No runtime or
benchmark configuration changes. The evidence retains every case and derives
23 scaling groups, 27 annotation pairs and 15 informational C comparisons.

At 16/64/256 KiB, Swift time grows 6.70–17.21× for about 16× input bytes,
without an observed strongly superlinear pattern in this bounded series.
This does not prove complexity or robustness at other inputs/sizes. At
256 KiB, long-emphasis syntax collection costs **6.41×** and raises malloc
requests from **56 to about 262 K**. Open brackets request about **174 M gross
bytes**, despite few allocations and a faster time than this C control.
Invalid UTF-8 takes **3.33× C time**, with C's optional UTF-8 validation disabled;
that comparison is not equivalent work. Profile these demonstrated costs next.

The existing 72-case gates remain unchanged and are not rerun here. Historical
correctness/preparation tests remain under their original identities. Linux/
minimum-compiler checks of the new harness, current-candidate ARM64, fresh
progressive resource measurements and broader fuzz/sanitizer work remain open.
No peak-memory reduction, new runtime optimization or completed M7 is claimed.

## Measured token allocation optimization

The subsequent [token arena report](../Validation/M7/token-arena-2026-11-22.md)
profiles the demonstrated annotation cost, then changes three internal parser
files. A controller-local token arena and reused emission buffer replace
per-item token arrays; the existing single-segment mapper avoids temporary
token range arrays, preserving empty CRLF positions and nested rebasing.
Public API, source grammar, validation, fixtures and budgets are unchanged.

At 16/64/256 KiB, deep-emphasis annotation time improves **75–77%**; the large
case takes **29.721 → 7.279 ms**, lowering its paired annotation multiplier
from 6.23× to 1.67×. Separate allocation profiles record **262,219 → 94
requests per parse (99.964% fewer)** and about **5.7% less gross requested
volume**, without establishing live/peak memory. A small initial M5 slowdown
does not recur in the recorded order-reversal check; no broad M5 speedup is
claimed. The 174 M bracket-buffer traffic remains a separate cost.

Current validation passes **247 library tests / 29 suites** in Debug/Release
on macOS and native Linux ARM64, **10 Mac Release tool/reference tests** and
**36 Python tests in each mode**. All 1,324 old/new spec token tables match
exactly, including 4,422 roles/ranges/owners in array order. Targeted 30-case
subsets per variant pass all six Mac C/absolute and nine frozen M2 checks.

The complete 69-case baseline above remains historical to its recorded source.
This candidate still needs minimum Swift 6.2/current x64, Linux development-
tool timings, full benchmark refresh and fresh progressive resource evidence.
Next profile large item/bracket buffers, then malformed-byte decoding with an
explicit validation-enabled C control. Broader fuzz/sanitizer work and M7
acceptance remain open; no push, PR or publication occurs in this step.

## Measured inline buffer and emission capacity optimization

The [next candidate](../Validation/M7/inline-capacity-2026-11-22.md) addresses
growth traffic in the inline controller and output builder. Private optional
links use compact integer storage behind the existing accessors; bracket
fields are grouped; known item counts provide a conservative emission hint.
Growth stays geometric across small leaves. Public API, node granularity,
index validation, grammar, inputs and performance limits are unchanged.

For open brackets at 256 KiB, gross requested bytes fall **174,190,788 →
119,819,700 (31.21%)**, and requests **76 → 51**. Internal item/bracket strides
are **144 → 120 / 32 → 24 bytes** on this Mac; public nodes remain 128.
Bracket timing is broadly maintained; long-emphasis syntax-on improves a
further 6.94–10.66% in the paired subsets. Neither gross traffic nor private
slot size establishes peak RSS or retained heap.

Both direct 30-case variants complete and all six Mac C/absolute plus nine
M2 checks pass unchanged. Current validation passes **249 library tests /
29 suites** in Debug/Release on macOS and native Linux ARM64, plus **10 Mac
Release tool tests**. All 1,324 old/new public snapshots match: 7,994 nodes
with payload/ranges/segments/links and 4,422 tokens. Unchanged Python scripts
are not retested in this step. Source/executable identities and all evidence
remain in the linked report/data directory.

Next investigate malformed-byte processing with an explicit validation-enabled
C control. Current x64/minimum Swift 6.2, Linux tool timings, full 69/72 refresh,
fresh progressive stage/RSS/allocation evidence and broader fuzz/sanitizer
checks remain open. Historical measurements keep their earlier identities;
this local step does not accept or merge M7.

## Explicit UTF-8 controls and validated snapshot reuse

The [UTF-8 report](../Validation/M7/utf8-2026-11-22.md) follows the malformed-byte
profiling priority. A separate 36-case target selects C validation off/on for
legacy malformed, compatible malformed and valid multibyte inputs. It verifies
matching repaired HTML where intended and preserves the known legacy policy
difference; original-byte source-coordinate work still differs between parsers.

One runtime file avoids rebuilding an already validated canonical plain
paragraph when no inline rules, triggers or rendering-policy work remain.
At compatible malformed 256 KiB, M2 syntax-off time improves 12.812 → 10.297 ms
(19.63%), with validating C 5.259 → 5.251 ms. Swift/C is 1.96× after; parity
remains an aim. Gross requested bytes fall 53.05%, with almost unchanged
allocation count and no peak-memory claim.

All 252 Mac tests pass in Debug, Release and AddressSanitizer; 12 Release tool
tests pass, all 1,324 public snapshots match, and the standalone bounded ASan
stress probe completes 8,192 parses. The later
[current x64/resource/minimum-compiler report](../Validation/M7/final-x64-2026-11-22.md)
passes full 36/69/72 target refreshes, native suites, 42 source-matched resource
cases and Swift 6.2 CI. A [coverage-guided campaign](../Validation/M7/fuzz-2026-11-22.md)
uses the already installed system Clang runtime, completing 3,510 units without
failure; the Linux executable does not enable ASan. See
[candidate readiness](M7Readiness.md) for the complete gate/limit table. This
candidate does not accept M7 or publish 0.7.0.
