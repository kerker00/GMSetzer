# M6 self-review before push

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

21 November 2026. Reviewed the complete `origin/main...5711a3a` change and
the corrections on `feature/m6-validation`, at the owner's request before
any push or PR. Scope includes the prepared/group-output API, shared extension
context, HTML safety, concurrency/cancellation, tests, measurement tools,
archived evidence and current documentation.

## Findings and corrections

### R1 — P2: historical source identity missed new files

`load_evidence(..., source_root=...)` checked only paths already named in the
receipt. A checkout with an additional `Sources/SetzerHTML/Unmeasured.swift`
incorrectly accepted the old measurement identity. This was reproduced before
the correction. The old hash check did not establish that the complete runtime
source set was unchanged.

**Fixed:** compare the complete runtime source inventory as well as file hashes,
rejecting additions, removals and renames. `--source-root` now checks the runtime
manifest and all 42 runtime Swift files. `--include-measurement-tools` additionally
checks the probe source inventory and hashes. Runtime evidence and exact harness
reproduction have separate, explicitly reported scopes. A changed harness must
not silently invalidate or relabel historical measurements of unchanged runtime
sources. Regression tests cover both scopes and source-set changes.

### R2 — P2: measurement provenance was hard-coded

The runner always wrote revision `087e694`, claimed unchanged runtime sources
and queried a compiler at a fixed user-local Swift 6.4.2 path. Running it on a
different checkout/compiler could therefore write misleading metadata. It also
classified every nonempty stderr as the known backtrace warning.

**Fixed:** obtain the real Git revision and runtime dirty/inventory state.
Source-only transfers without their own Git checkout report unknown revision/
dirty state, retaining exact source hashes. Select the compiler from `--swift`
or PATH, and retain actual stderr messages with process addresses normalised.
The source inventory now includes additional probe Swift/Python/C files too.
Tests exercise clean, staged/unstaged and newly added sources in a real temporary
Git repository, parent-repository rejection, inventory compatibility and stderr
handling. Compiler metadata describes the declared environment; an arbitrary
supplied binary still requires the documented build/provenance checks.

The old receipt is not rewritten. All 48 archived source/tool hashes were
independently matched against files read from commit `fe6a505`; its known
provenance is retained. The corrected runner has no new Linux matrix result.

### R3 — P2: incomplete raw-record validation and removable guards

The evidence loader did not compare group/fallback metadata with the raw
verification/timing records, did not check RSS pipeline mode, and could raise
an unhandled `IndexError` for an empty verification sample array. The runner's
instrumentation/equality assertions disappeared under Python optimisation.

**Fixed:** validate sample counts, pipeline mode, configuration, structural
metadata, individual stage measurements and grouped byte totals. Invalid data
returns the documented error status 2; budget overruns retain status 1. Use
explicit exceptions for runner verification, so `python -O` cannot remove it.
Tests mutate archived records and summaries with updated checksums and verify
that inconsistencies are rejected, including the CLI error path.

### R4 — P2: cancellation coverage overstated an exercised boundary

The existing "before and during" test threw at checkpoint 2, before the first
renderer event, so it did not exercise interruption after partial construction.

**Fixed:** name that test accurately and add three focused tests: cancellation
after an opening tag without partial delivery or later-hook evaluation; actual
Swift task cancellation before the next group; and lazy footnote appendix
hooks when body consumption stops. The reusable plan still renders correctly
after interruption. No runtime change was required.

## Renderer and API assessment

No P0/P1 rendering/security/concurrency defect was found in the reviewed diff.
The implementation reuses the existing event renderer and complete immutable
document. It does not parse slices or generate full HTML before structural
requests. Contextual hooks retain the shared index; footnotes retain global
numbering, references and one deferred appendix. Per-request output/event state
is local. Uncertified hooks, root hooks and raw HTML have explicit conservative
fallbacks. Safe escaping/URL/comment/anchor behavior is shared with full output.

The known limits are deliberate and remain documented: full parsing and global
preparation precede output; a giant block/appendix is indivisible; arbitrary
caller hooks and literal conversions cannot be interrupted internally; a soft
source-byte budget is not an HTML-byte or total-memory cap. Independent hook
certification is a caller contract. No speculative renderer rewrite or
optimisation is introduced by this review. Runtime sources, package manifest,
development version and protected specification fixtures are unchanged.

## Validation after correction

- macOS/Swift 6.4.2 Debug: **242 tests in 28 suites pass**, 0.931 s test runtime.
- macOS/Swift 6.2 Debug: **242 tests in 28 suites pass**, 0.566 s test runtime.
- macOS/Swift 6.2 Release: all **14 progressive-output tests** pass, including
  the new cancellation/deferred-appendix checks, 0.002 s test runtime.
- All **31 offline Python tests** pass in normal and `-O` modes.
- All 652 CommonMark and 672 GFM protected examples pass; grouped/full equality
  over both corpora in safe/conformance modes is included in the Swift suites.
- **42/42 historical matrix cases pass** the unchanged post-baseline budgets.
  The current runtime's 43 manifest/source hashes and complete inventory match.
  All 48 historical runtime/tool files at `fe6a505` match the archived receipt.
  The explicit harness check correctly rejects today's changed runner.
- Documentation file links and `git diff --check` pass.

No full performance matrix, Linux run, push, PR, merge or release was performed
for this review. Linux/Swift 6.2 CI, owner API/budget review and merge remain
open. The host/toolchain/SDK setup and original measurement limits remain in
[review readiness](../Validation/M6/review-readiness.md) and the historical M6
validation records.
