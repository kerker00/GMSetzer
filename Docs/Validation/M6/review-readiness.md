# M6 review readiness and post-baseline budgets

21 November 2026, `feature/m6-validation`, based on `fe6a505` and the initial
M6 implementation at `087e694`. Development identity remains `0.6.0-dev.1`.
This follow-up adds an offline evidence/budget checker and documentation;
runtime sources, package manifest, parser grammar and protected fixtures are
unchanged. This records the initial checkpoint at `5711a3a`; the subsequent
[self-review](https://github.com/kerker00/GMSetzer/blob/418882ff66357ce17e968d389b62d77296d665db/Docs/Review-M6.md) corrects the measurement tools and expands
coverage to 242 Swift and 31 Python tests without changing runtime sources.
The original implementation branch was recovered into a persistent workspace
worktree; the original `main` checkout and its uncommitted plan changes are
preserved.

## Quantitative criteria for review

These implementation-level budgets are selected **after** the recorded
[42-case baseline](linux-arm64-measurements.md), as required by Plan 10.1.
They are now explicit candidates for owner review, not pre-registered targets
or an independently repeated experiment. Every workload, size and annotation
configuration must pass individually. Faster cases cannot compensate for a
failure elsewhere. The broader M7 parse/C limits remain unchanged.

Times compare complete-document preparation plus first output, or preparation
plus consumption of every group, with full HTML rendering on the **same parsed
document**. They exclude parsing and application transfer/layout. Parsing is
still required before any output; end-to-end figures remain in the baseline.

| Criterion | Budget | Worst recorded result |
| --- | --- | --- |
| First output, independent blocks at 100 KB | At most 75% of full HTML time | 42.72%, all-M5, syntax details off |
| First output, independent core blocks at 1 MB/5 MB | At most 25% of full HTML time | 9.21%, small blocks at 1 MB, details off |
| First output, selected all-M5 composition at 1 MB/5 MB | At most 50% of full HTML time | 32.51%, 5 MB, details off |
| Complete grouped consumption, every case | At most 110% of full HTML time | 103.88%, small blocks at 1 MB, details off |
| Whole-process peak RSS, first/all groups | At most the greater of 110% of full-render RSS or full-render RSS + 8 MiB | Largest absolute increase: 0.55 MiB |

One long fenced code block has **no earlier-output budget**. It must remain
one group and still satisfy completion/RSS budgets. This exception is limited
to that explicit workload; an unexpected whole-document fallback fails the
matrix check. Raw-HTML and document-order-hook fallbacks are separately covered
by functional tests. The footnote appendix remains one indivisible group.

RSS is whole-process high-water memory, including source generation and the
parser. This is a guard against additional overhead, not a claim of memory
reduction, a bound on retained memory or a bound on group HTML bytes.
The archived allocation counts/volume remain descriptive evidence; no
allocation-reduction target is introduced. Medians and these generous relative
budgets do not turn the uncontrolled host samples into statistical proof.

## Reproducible offline check

From the repository root:

```sh
python3 -I Scripts/check_progressive_html_budget.py \
  Docs/BenchmarkData/m6-progressive-html/linux-arm64-2026-11-21 \
  --source-root .
python3 -I -m unittest discover -s Scripts
```

The checker verifies artifact SHA-256 values, all 42 exact HTML verification
records, eight alternating uninstrumented timing samples per case, raw timing/
summary agreement, three fresh uninstrumented RSS processes per mode, sample
medians, configuration and completeness. It reads archive members without
extracting them. Following self-review, `--source-root` checks the runtime
manifest, complete source inventory and all 43 runtime/manifest hashes, and
must be used when applying historical evidence to a runtime checkout. Add
`--include-measurement-tools` to require the historical harness inventory and
hashes as well (48 files for this record). This stricter check passes at
`fe6a505` and correctly rejects the subsequently improved runner. Omit source
matching only when inspecting the historical measurements themselves. A changed
runtime needs fresh measurements before the old evidence can be applied again.
Exit codes are 0 for passing budgets, 1 for budget failures, 2 for invalid or
incomplete evidence. No benchmark, network access or measured binary is run.

The check passes **42/42 cases** against the unchanged implementation. Seven
initial Python regression tests cover per-case failures, the giant-block exception,
RSS overruns, missing/duplicate cases, invalid samples, changed configuration,
corrupt artifacts, source mismatch and isolated CLI execution. All **24 offline
Python tests** passed at `5711a3a`; [self-review](https://github.com/kerker00/GMSetzer/blob/418882ff66357ce17e968d389b62d77296d665db/Docs/Review-M6.md) expands
this to 31. Normal regression tests inspect historical evidence without
freezing future library sources to the baseline's hashes.

## Fresh compiler validation

macOS 27.0.1 arm64, existing Xcode 27.2/Apple Swift 6.4.2:

- Complete Debug suite: **239 tests in 28 suites pass**, 0.828 s test runtime.
- All 652 CommonMark and 672 GFM protected examples pass. The grouped/full
  comparison covers both complete corpora in safe and conformance modes.

The official Swift 6.2 macOS package was downloaded from Swift.org, checked
using `pkgutil --check-signature` and `spctl -a -vv -t install`, then extracted
under a task-specific `/private/tmp` directory without installing it or changing
Xcode selection. It is signed by Swift Open Source (`V9AUD2URP3`) with a trusted
timestamp and accepted by the Apple notary service. The initial sandboxed
signature check could not access the signing subsystem; the permitted external
check succeeded before execution. Package SHA-256:
`9eac4a13500c7a6dedfd90814fd31c17af2efc38150137b56b70bf5f44b2d64b`.

Swift 6.2 uses the existing Command Line Tools macOS 14.4 SDK, its own Testing
module/runtime and isolated scratch/cache/configuration/security/module paths,
as described in [Portability](https://github.com/kerker00/GMSetzer/blob/418882ff66357ce17e968d389b62d77296d665db/Docs/Portability.md#reproduction). The deployment
minimum remains macOS 15; this does not prove minimum-OS runtime behavior.

- Complete Swift 6.2 Debug suite, `swift test --disable-sandbox --disable-xctest`
  with the SDK/Testing flags: **239 tests in 28 suites pass**, 0.597 s runtime.
- `swift build -c release --disable-sandbox` with the same SDK and isolated
  paths: all runtime modules build, 25.92 s.
- At this initial checkpoint, all 48 measured source/tool hashes matched the
  Linux baseline exactly. After self-review, the unchanged runtime matches all
  43 runtime/manifest hashes and the historical `fe6a505` checkout still matches
  all 48; the current runner intentionally differs.

## Remaining review and CI

The initial [macOS/Linux validation](initial-html-groups.md) and Linux ARM64
resource matrix remain evidence for the same runtime sources. PowerG5 did not
answer an SSH connection during this follow-up, so no fresh Linux run is
claimed and no replacement VM/container or toolchain installation was made.
Swift 6.2 execution on Linux remains pending the existing macOS/Linux PR CI
or restored access to a host with that compiler. The new Python checker has
been executed locally on macOS, not freshly on Linux.

The implementation and review budgets are ready for review. M6 is not marked
complete: owner review of the API/budgets, PR/merged-main CI and owner merge
remain. Consumer scheduling, WebView/device acceptance, broad M7 hardening and
version publication are separate. No push, PR creation, merge, tag or release
was performed in this follow-up.


## Subsequent PR #24 CI validation

[PR #24](https://github.com/kerker00/GMSetzer/pull/24) was created and
[CI run 44926163013](https://github.com/kerker00/GMSetzer/actions/runs/44926163013)
passed at source commit `bcf0291682e6c544a41f601229dc99715627897b` on
21 November 2026. This closes the Linux/minimum-compiler and fresh Python
execution gaps recorded above. Subsequent status changes are documentation
only; runtime, tests, tools and protected fixtures retain that tested content.

| Environment | Result |
| --- | --- |
| macOS 26, Xcode 26.2, Apple Swift 6.2.3 | 242 Swift tests in 28 suites, 652/652 CommonMark and 672/672 GFM examples, optimized build and 31 Python tests pass |
| Ubuntu 24.04, Swift 6.2 | 242 Swift tests in 28 suites, both protected corpora, optimized build and 31 Python tests pass |

The updated runner/evidence-checker regression tests execute successfully on
both CI hosts. This is not a new measurement matrix or execution of the Linux
resource runner; its timing/RSS/allocation record remains historical. Owner
API/budget review, merge and any release remain open. No CI workflow was changed.
