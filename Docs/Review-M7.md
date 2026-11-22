# M7 implementation self-review

22 November 2026. Recorded review scope is `59bc567..dd075ee`, covering the
`feature/m7-hardening` candidate, including the UTF-8 step measured over
`e3b4b0c` and committed in `8ab9786`, plus the subsequent development fuzz
harness. This is a self-review, not independent external review or M7
acceptance. Runtime changes are limited to five existing files; public grammar,
API contracts, limits, dependency pins and protected specification IDs remain
unchanged except the separate `0.7.0-dev.1` development identity.

## Implementation checks

- Scratch child/event/token-order buffers belong to one parse and do not
  escape into immutable documents. Each traversal drains the event stack;
  retained capacity avoids repeated per-node allocation.
- Inline item links use private `-1` sentinels through existing optional
  accessors. Public node indices and document validation keep their original
  representations. Compact bracket field layout is an implementation detail,
  not an ABI guarantee.
- Token arena links preserve per-item insertion order on emission. Nested
  extension parsing rebases item links, token tails, previous links and source
  coordinates independently. Single-piece and empty CRLF mappings retain exact
  original ranges. Dedicated regressions and all 1,324 public snapshots agree.
- Builder reservations use an upper bound from parsed items and geometric
  growth across both builder arrays. They preserve amortized growth across
  many small leaves; unused capacity and peak RSS remain measurement concerns.
- Plain-paragraph reuse requires canonical physical storage and complete
  text/soft-break coverage. It rejects custom inline rules and rendering-policy
  work before returning an already validated snapshot. Reordered transform
  storage, rule factories, code-block info decoding and original malformed-byte
  coordinates retain their existing behavior. No unchecked construction or
  compiler mode is introduced.
- Library code remains dependency-free and Foundation-free. Development-only
  C/benchmark/stress tools stay outside the root package. C timing feeds raw
  bytes; validation and repair-policy differences are explicitly labelled.

## Evidence and limits

The [UTF-8 validation report](Validation/M7/utf8-2026-11-22.md) records current
252-test Mac Debug/Release/ASan suites, 12 Release tool tests, 36 Python tests
per mode, 8,192 bounded ASan parses and exact public snapshots. Current full
Mac 69/72-case exports and unchanged C/M2 gates pass. Source/executable hashes
and failed tooling attempts are retained rather than silently discarded.
Each earlier optimization retains its own paired measurements and limits.

No additional runtime correctness issue was found in this review. This is not
a proof against all inputs. The [subsequent x64/resource/minimum Swift 6.2 checks](Validation/M7/final-x64-2026-11-22.md)
pass, and a [bounded coverage-guided campaign](Validation/M7/fuzz-2026-11-22.md)
completes 3,510 units without failure. The development callback is isolated from
the root package, retains assertions, checks source/semantic/HTML invariants and
has process/input/RSS bounds. Its runner verifies coverage symbols/execution,
uses existing Clang archives and preserves failed commands; no installation is
introduced. This Linux executable has no ASan; Mac ASan retains its own scope.
General C parity, larger-input/peak-memory conclusions and a future HTML
byte-buffer rewrite are not established.
The owner merged PR #26 at `a273810` after this review. Explicit M7 acceptance
and release publication remain separate steps.
