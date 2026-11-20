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
checks are recorded below when completed. No new tests duplicate the helper
structure; the existing behavioral suites remain the acceptance basis.

Shared configuration/registry dispatch, hook context, inline extension rules,
token/fallback storage and a measured inline budget remain subsequent M1-C
work. This step moves decomposition ahead of that work instead of repeating
the refactor in M1-D. It does not implement inlines or complete M1 acceptance.
