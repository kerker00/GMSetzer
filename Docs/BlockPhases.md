# Block phase boundaries before shared rule dispatch

The M1-C preparation separates the block-parser loop into named internal phases.
There is no public API, profile, rule-order or syntax change.

1. `matchOpenContainers` projects the physical line through the still-open
   containers and records how many matched.
2. `continueOpenLeaf` handles fenced/indented code, setext conversion, HTML
   continuation and lazy paragraph continuation. It reports whether the line
   was consumed; the driver advances exactly once.
3. Otherwise the driver finishes the leaf and closes unmatched containers.
   `consumeBlankLine` retains the existing blank-separation bookkeeping.
4. `openContainers` preserves extension/quote/list precedence and list-item
   continuation. Its result is either a consumed extension with an explicit
   next-line index or a leaf start with an explicit depth-limit state.
5. `startLeaf` retains the existing indentation/fence/heading/thematic-break/
   HTML/paragraph precedence. A blank remainder after opening containers does
   not receive the earlier blank-separation bookkeeping a second time.

The driver remains iterative, including multi-line extension progress and EOF
closure. Helper extraction reads kind/parent without copying the open leaf's
growing indices array; continuation appends through the optional's mutable
accessor. The former `leaf!` accesses and the two control flags disappear.
Builder `try!` sites retain their existing invariant policy pending the M1-D
audit; this refactor does not introduce silent tree-validation recovery.

Existing tests cover nested/tight/loose lists, quotes, lazy continuation,
reference-only setext cases, HTML termination, tab projection, depth fallback
and multi-line extension boundaries. All 57 library tests and 3,919 pinned-C
comparisons pass after extraction. Further toolchain/platform/performance
checks are recorded below. No new tests duplicate the helper
structure; the existing behavioral suites remain the acceptance basis.

Shared configuration/registry dispatch, hook context, inline extension rules,
token/fallback storage and a measured inline budget remain subsequent M1-C
work. This step moves decomposition ahead of that work instead of repeating
the refactor in M1-D. It does not implement inlines or complete M1 acceptance.

## Verification of the extracted phases

The measured/tested core is `4c4fd464d8b5532b8c221e5438bfdd1978e42da0`.
Subsequent integration of the portability proof changes development tools and
documentation, with no further runtime-source changes.

- All 57 library tests pass with Swift 6.4.2 on macOS in debug and release,
  and with Swift 6.2 using its matching Testing runtime and the compatible SDK.
- All 57 tests also pass on an existing SSH Linux host: x86-64, Linux
  7.3.3-1-cachyos, glibc 2.44, Swift 6.4.2. Only manifest/source/fixtures were
  transferred into a new task-specific directory, which was removed after
  verifying the captured output. No VM, container, install or service change.
- All five refactored modules also cross-build for static Linux ARM64 with
  Swift 6.2. This step does not claim another ARM64 runtime execution or a
  full Linux Swift 6.2 test-framework run.
- All 3,919 pinned-C comparisons and eight offline Python tests pass.

The authorised full 30-case release countermeasurement passes all six absolute/
C-ratio budgets and the explicit 10% regression alert against the frozen M1-B
baseline. Core timings are 2.615 / 26.132 / 132.514 ms at 100 KB / 1 MB / 5 MB;
changes of this size relative to M1-B are not claimed as an optimisation.
Remaining measured core headroom is 0.871 / 11.290 / 58.588 ms, covering all
future parse work rather than exclusively the inline phase. The incomplete
inline/GFM scope and non-additive phase-median caveats remain unchanged.

The [receipt](Validation/BlockPhases/receipt.json),
[raw benchmark output](Validation/BlockPhases/benchmark.md),
[budget report](Validation/BlockPhases/budget.json) and test summaries alongside
them retain source/artifact hashes and toolchain/architecture scope. Private
SSH connection details are not part of the evidence.
