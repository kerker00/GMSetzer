# Development status and history

23 November 2026. The latest published preview is [v0.6.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.6.0).
The M7 candidate merged in [PR #26](https://github.com/kerker00/GMSetzer/pull/26)
at `a273810`, with identity `0.7.0-dev.1`. It is not a published 0.7 release;
explicit milestone acceptance and release preparation remain separate. See
[candidate readiness](M7Readiness.md) for its current checks and limits.
The scan/Span experiment merged in [PR #27](https://github.com/kerker00/GMSetzer/pull/27)
at `6372cfc`, after the README reorganisation. It leaves the production scanner
unchanged; the measured variants do not justify blanket adoption. The
[HTML-copy follow-up](Validation/M7/html-copies-2026-11-22.md) merged in
[PR #28](https://github.com/kerker00/GMSetzer/pull/28) at `ce5dedc`, with 253-test
native suites, minimum Swift 6.2 CI and source-matched resources. The subsequent
inline-input/comparison work merged in
[PR #29](https://github.com/kerker00/GMSetzer/pull/29) at `49afec9`.
M8 merged in PR #30 at `5f81308` with identity `1.0.0-dev.1`: validated HTML convenience
rendering, six DocC catalogs, a source API candidate inventory and Index
configuration and a project-focused [roadmap](Roadmap.md). All source-owned
public types/typealiases have summaries. At `cbdc977`, minimum Swift 6.2 CI
passes 263 Swift tests, both protected corpora, 61 Python checks and optimized
builds on macOS/Linux, plus all six DocC archives and 610 source API declarations.
Merged-main CI run 45131801793 also passes all three jobs at `5f81308`.
The owner confirmed the merge and requested the 1.0 release-preparation step.
`release/1.0.0` now prepares the final identity, notes and frozen API baseline;
[candidate verification](Validation/Release/1.0.0.md) is recorded separately.
See [readiness](M8Readiness.md) for the checked scope and open
1.0 review/release gates. Input streaming needs a
separate design for global definitions and document ownership.

## Historical checkpoints

The following chronological notes were moved from the README. Test counts,
open work, branch identities and timings describe each recorded checkpoint;
they do not override the current status above or their linked evidence.

> **Status, 21 November 2026:** M1–M6 are merged in `main`. M5 has
> [functional acceptance](M5Acceptance.md); M6's progressive-output
> [library gates are accepted](M6Acceptance.md). Merged-main CI passes
> 242 Swift tests, all 652 CommonMark and 672 GFM examples, optimized builds
> and 31 Python tests on macOS/Swift 6.2.3 and Linux/Swift 6.2. The latest
> published source-only preview is [v0.6.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.6.0), including M6.

[PR #24](https://github.com/kerker00/GMSetzer/pull/24) (`a8a0351`) adds
**progressive HTML**; its accepted M6 snapshot used identity `0.6.0-dev.1`.
That implementation is published separately as source-only **v0.6.0** at
`8ff2061`, after [PR #25](https://github.com/kerker00/GMSetzer/pull/25) merged.
See its [release notes](Releases/0.6.0.md) and
[validation](Validation/Release/0.6.0.md).
This M7 branch now reports **`0.7.0-dev.1`** and retains the new hardening/
optimization work for the next preview.
`HTMLRenderer.prepare` and `FootnotesHTMLRenderer.prepare` retain complete
Markdown context and emit structural HTML groups on demand, with explicit
whole-document fallbacks for raw HTML and document-order hooks. The
[API and limits](ProgressiveHTML.md), [self-review](Review-M6.md)
and [M6 acceptance](M6Acceptance.md) describe the supported contract.

For the accepted M6 snapshot, the 42-case Linux ARM64 stage/RSS/allocation
matrix meets the reviewed post-baseline budgets. Mixed 1 MB/5 MB inputs reach
first HTML in about half the parse-plus-full-output time on that host. Full parsing still precedes
output; giant blocks remain indivisible and no general peak-memory reduction
is established. The [0.6.0 installation](../README.md#installation) includes progressive output.

Current work is **M7: general speed and hardening**, with reproducible
adversarial/mutation coverage and a measured investigation of remaining costs.
API/DocC/1.0 completion stays **M8**. Full benchmark and long fuzzing execution
follow the existing approval requirement.

The initial `feature/m7-hardening` step adds bounded deterministic mutation
coverage: 1,024 profile/input combinations and 24 depth cases across strict,
GFM and selected M5 configurations. At that preparation checkpoint, all 245
tests pass in Debug and Release on macOS and native Linux ARM64/x64 with
Swift 6.4.2. The owner-approved [72-case Apple M2 baseline](Validation/M7/baseline-2026-11-21.md)
passes all six parser/C budgets and nine frozen M2 checks. The separate
[72-case Raspberry Pi baseline](Validation/M7/linux-arm64-2026-11-21.md)
satisfies all six same-host C ratios, with high-load/sample-count limitations.
The [direct x64 baseline](Validation/M7/linux-x64-2026-11-21.md) also
passes all six C ratios: GFM is within about 7% of C on this corpus; CommonMark
is 33–62% slower and remains the parser profiling priority toward parity.

The [first measured optimization](Validation/M7/inline-scratch-2026-11-21.md)
reuses inline scratch buffers: CommonMark time improves 15–17% on M2 and 6–7%
on x64; the 1 MB Mac allocation profile records about 48% fewer requests.
That step's macOS/x64 Debug/Release suites and Release C-reference tests pass;
CommonMark is 24–54% slower than C in its x64 series. Minimum-compiler
checks, fresh progressive resource measurements, larger-input scaling
and broader fuzzing remain open. See [M7 hardening](M7Hardening.md)
for scope, reproduction and remaining portability/performance gates.

The separate [extension/hostile-input matrix](M7HardeningWorkloads.md)
completes **69/69 Mac cases in 5 min 26 s**, at 16/64/256 KiB with syntax
details off/on, composed M5 rendering and informational C controls. The
[scaling report](Validation/M7/hardening-scaling-2026-11-22.md) observes
approximately proportional timing, while identifying expensive deep-emphasis
tokens, large bracket buffers and malformed-byte processing for profiling.
The preparation's ten Release tool tests and 36 Python tests in both modes
remain valid for the unchanged harness. New-harness Linux/minimum-compiler
validation, resource/fuzz work and M7 acceptance remain pending; existing
reference cases and budgets are unchanged.

The subsequent [token arena optimization](Validation/M7/token-arena-2026-11-22.md)
reduces deep-emphasis annotation time by **75–77%** on the Mac: the large
case takes 29.721 → 7.279 ms, with **262,219 → 94 malloc requests** per parse.
Gross requested bytes fall about 5.7%; peak memory is not established. All
247 library tests pass in Debug/Release on macOS and native Linux ARM64,
10 Mac tool/reference tests pass, and all 1,324 old/new specification token
tables match exactly. Current targeted C/M2 checks pass unchanged. The full
69-case baseline predates this three-file runtime change; wider measurements,
minimum compiler and current x64 execution remain pending. Next are the large
bracket buffers and malformed-byte path; M7 is still in progress.

The [buffer follow-up](Validation/M7/inline-capacity-2026-11-22.md) reduces
gross requested bytes for the 256 KiB bracket case by **31%**, from about
174 M to 120 M. Internal slots are smaller and large inline output reserves
its capacity in batches; public nodes stay identical. All **249 library tests**
pass in Debug/Release on macOS/Linux ARM64, with 10 Mac tool tests and all
C/M2 gates passing. Independent snapshots match all 1,324 spec trees/tokens.
Bracket timing is broadly maintained; no peak-RSS reduction is established.
The [UTF-8 follow-up](Validation/M7/utf8-2026-11-22.md) adds explicit
validation-on/off C controls without changing the legacy corpus or Swift's
replacement policy. Reusing an already validated plain-paragraph tree reduces
the compatible malformed 256 KiB case from **12.812 to 10.297 ms** and gross
requested bytes by **53%** on M2. Validating C takes 5.251 ms; this is still
1.96× C time, with different source-coordinate services. All **252 Mac library
tests**, 12 Release tool tests, the full AddressSanitizer suite and a bounded
8,192-parse ASan mutation run pass. This is not coverage-guided fuzzing.
The [current x64/resource report](Validation/M7/final-x64-2026-11-22.md)
records passing native suites/tools, all 36/69/72 benchmark cases and a fresh
42-case progressive matrix with matching runtime/tool hashes. Swift 6.2 CI
passes on macOS/Linux. A separate [coverage-guided campaign](Validation/M7/fuzz-2026-11-22.md)
completes 3,510 units without failure using the existing Linux Clang runtime.
See [candidate readiness](M7Readiness.md): owner review/acceptance and
general C parity remain open; there is no 0.7 release yet.

Merged PR #17 (`0434ff5`) adds an optional English/German lookup for native
findings and fix titles on `main`, with a documented
[message-key/argument catalogue](NativeAnalysisMessages.md). The v0.4.0
release still supplies English defaults only.

Merged PR #18 (`4397819`) adds exact quote/list marker tokens on `main`;
see [ContainerMarkers](ContainerMarkers.md). Its PR and merged-main CI
pass on macOS and Linux. These features are included in v0.5.0;
M5 is now functionally accepted across the separately merged steps below.

Merged PR #19 (`4b0f105`) adds opt-in raw YAML/TOML front matter on `main`
through the existing extension API; see [FrontMatter](FrontMatter.md).
Its PR and merged-main CI pass on macOS and Linux.

Merged PR #20 (`a6a2da6`) adds named footnotes, source-spelled tokens,
numbering and a separate HTML renderer with backlinks on `main`; see
[Footnotes](Footnotes.md). PR and merged-main CI pass on macOS and Linux.

Merged PR #21 (`6f166b7`) adds opaque inline/display/fenced TeX on `main`
with exact provenance and caller-owned rendering; see [Math](Math.md).
PR and merged-main CI pass on macOS and Linux.

Merged PR #22 (`c9543fe`) adds GitHub-style alerts and
Obsidian-style callouts with parsed titles, folding and an optional HTML
recipe; see [Admonitions](Admonitions.md). PR and merged-main CI pass
on macOS and Linux. [M5 functional acceptance](M5Acceptance.md) is
complete. PR #23 (`2d8ecef`) prepared the published v0.5.0 preview with
[release notes](Releases/0.5.0.md), result identity `0.5.0` and
[release validation](Validation/Release/0.5.0.md).


## Earlier module milestones

M1 acceptance is merged in PR #9 and block hot-path optimisation in PR #10.
M2 adds CommonMark inlines and 867 exact C comparisons. M4 adds GFM as typed
built-in nodes, compared with cmark-gfm; see [Docs/M4GFM.md](M4GFM.md).
