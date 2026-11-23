# M7 candidate readiness

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

22 November 2026. The M7 candidate merged in [PR #26](https://github.com/kerker00/GMSetzer/pull/26)
at `a273810`. Explicit milestone acceptance remains separate, and no 0.7
tag/release exists.
The recorded M7 development identity is `0.7.0-dev.1`; the latest published
version stays 0.6.0. [M8 preparation](M8Readiness.md) now uses `1.0.0-dev.1`.
The measurements here keep their original source identities.

The table below records the merged PR #26 snapshot. The subsequent
[HTML-copy follow-up](../Validation/M7/html-copies-2026-11-22.md), merged in PR #28
at `ce5dedc`,
adds a byte-fidelity regression test (253 total), profiled renderer gains,
fresh native resource/ASan checks and passing minimum Swift 6.2 CI. Its own
source hashes identify that changed renderer; earlier receipts remain history.

The later [inline-input follow-up](../Validation/M7/inline-input-2026-11-22.md),
merged in PR #29 (`49afec9`), records 256-test current suites, a retained-context capacity
review correction, 19.34% fewer 1 MB allocation requests, complete native
72/69/36-case refreshes, 42 source-matched resource cases / 126 checks and
minimum Swift 6.2 CI. Optional MD4C/pulldown comparisons expose a remaining
full-HTML throughput gap; the original ≤2× C parser gate and general C parity
remain distinct. That follow-up is merged but not released.

| Library gate | Candidate evidence |
| --- | --- |
| Protected grammar / public contracts | All 652 CommonMark / 672 GFM protected examples pass; 1,324 exact old/new snapshots retain 7,994 nodes / 4,422 tokens |
| Current correctness / portability | 252 tests in Debug/Release on Mac and native x64; 12 Release tool tests per host; earlier token/buffer stages also have native ARM64 evidence |
| Minimum compiler | Existing macOS Swift 6.2.3 / Linux Swift 6.2 CI passes 252 tests, optimized builds and 36 Python tests per host |
| Normal parser budgets | Complete 72-case Mac/x64 refresh; all six C/absolute and nine M2 Mac checks, plus six x64 C-relative checks pass unchanged |
| Selected extensions / hostile scaling | Full 69-case 16/64/256 KiB matrix on Mac/x64; 36 explicit UTF-8 controls per host, with policy/work differences labelled |
| Allocation evidence | Paired stack exports identify scratch/token/buffer costs; token requests 262,219 → 94, bracket gross bytes −31.21%, compatible malformed gross bytes −53.05%; no general peak-RSS claim |
| Progressive resource regression | All 42 current x64 cases / 126 checks pass, with 43 runtime + 5 measurement-tool hashes matching |
| Sanitizers / mutation | Mac ASan: 252 tests and 8,192 bounded stress parses pass |
| Coverage-guided robustness | Native x64 libFuzzer: 3,510 units in a bounded 180-second campaign, assertions/coverage enabled, no failures; ASan is separate |
| Self-review | [Implementation review](Review-M7.md), source/executable digests, unsuccessful tooling attempts and comparison limits retained |

Reports: [UTF-8 optimization](../Validation/M7/utf8-2026-11-22.md),
[current x64/resources/minimum compiler](../Validation/M7/final-x64-2026-11-22.md),
[coverage-guided campaign](../Validation/M7/fuzz-2026-11-22.md).

The declared same-host ≤2× C ceiling is met; parity remains the aim. Current
x64 mixed CommonMark takes 1.24–1.55× C time, while GFM takes 0.92–0.99×.
The compatible malformed control takes 1.90× validating C time, with different
original-byte coordinate services. Neither short fuzzing nor sampled scaling
proves all-input linearity or absence of all bugs. Longer/larger campaigns,
remaining intermediate copies and measured HTML emission improvements remain
useful follow-ups. Library evidence does not establish consumer device/UI
acceptance.

The owner merges are confirmed. Work now moves toward stable 1.0 in M8;
an intermediate 0.7 tag is not required. Release preparation must
choose its final version identity and exact merged commit, rerun required CI
and consumer/archive checks, and obtain separate confirmation before tagging
or publishing. The current candidate's matching receipts remain historical
evidence for their exact source identities; they must not silently identify
changed release sources as hash-equal.
