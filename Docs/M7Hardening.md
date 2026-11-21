# M7 speed and hardening

21 November 2026, initial work on `feature/m7-hardening`, based on the
accepted M6 runtime (`a8a0351`) and documentation follow-up `0cf6690`.
Development identity remains `0.6.0-dev.1`. This first step changes tests and
documentation only; runtime sources, public API, dependencies and protected
specification fixtures are unchanged. M7 is not accepted or merged yet.

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

macOS arm64, Xcode 27.2 / Apple Swift 6.4.2:

- Complete Debug suite: **245 tests in 29 suites pass**, including all eight
  mutation cases and all 652 CommonMark / 672 GFM protected examples.
- Complete Release suite: the same **245 tests pass**.
- The standalone public API and runtime dependencies are unchanged; the M6
  offline evidence checker still matches all 43 runtime/manifest files and
  passes 42/42 historical cases. This is no new timing/resource measurement.
- Minimum Swift 6.2 and Linux execution of the new tests remain for subsequent
  validation/PR CI. Their M6 predecessor has merged-main CI on both hosts;
  that is not substituted for running the three new tests there.

Commands use the native SwiftPM build system, `--disable-sandbox`, isolated
scratch/cache/configuration/security/module directories under `/private/tmp`,
and `-c release` for the optimized suite. The focused reproducer is:

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
[case list](Validation/M7/benchmark-cases.txt) and
[preparation identity](Validation/M7/preparation.json) are recorded. Build/list
does not execute benchmark samples. Development dependency objects were copied
from the existing local cache into task-specific storage; the original checkout
and its local changes were not used as the source under test.

The owner approved the complete series on 21 November 2026. It ran at clean
commit `1edf1a4`; all 72 cases complete and all four existing budget commands
pass. See the [measurement report](Validation/M7/baseline-2026-11-21.md) for
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

The first series supplies the existing C/absolute/frozen-M2 baseline. Next
profile HTML emission and add real-M5/hostile-input scaling/resource cases,
then expand the isolated fuzz/sanitizer campaign with minimized regressions.
Full benchmark and long-test/fuzz execution retain the owner-confirmation gate
in `CLAUDE.md`. M7 completion requires both the existing speed budgets and
documented robustness/allocation evidence; a passing small campaign alone does
not complete it. The measurement result is recorded locally; push, PR and release remain
separate steps.
