# M7 token arena evidence

22 November 2026. See the [report](../../Validation/M7/token-arena-2026-11-22.md).
Candidate scope is three runtime files and two public-behavior regression tests
over `c3758fc`; no clean-candidate-commit timing claim is made.

- `before.receipt.json`, `after.receipt.json`, `summary.csv`: two direct,
  unprofiled 30-case subsets (12 hardening + 18 mixed per variant), including
  all allocation unit labels, source/binary hashes and host-load observations.
- `comparison.json`: all 30 matched timing comparisons; small changes are not
  automatically speedups. `m5-repeat.json` retains the four-case order reversal.
- `allocation-before.json`, `allocation-after.json`, `allocation-summary.json`:
  separately instrumented stacks and per-iteration totals; not timing or RSS.
- `c-absolute.json`, `m2-*.json`, `budgets.json`: six plus nine passing checks,
  with existing limits unchanged.
- `candidate-source.json`, `change.patch.gz`: measured source/test identities
  and exact patch. Plain patch context whitespace is preserved inside gzip.
- `linux-source.json`, `linux-validation.json`: all 78 transferred source/test
  hashes and native Linux ARM64 Debug/Release receipts. Connection details and
  key material are excluded.
- `token-equivalence.json`: equality of 1,324 token tables / 4,422 entries;
  the complete before/after tables and independent probe are archived.
- `validation.json`: executed checks, pending gates and the evidence-collection
  correction. `logs.tar.gz` contains 53 sanitized streams/profiles/probe files.
- `artifacts.json`: archive hash and each original-to-retained digest mapping.
  `sha256.json` hashes retained data files, excluding itself.

Retained streams redact host/home/checkout names and process addresses, while
preserving numerical allocation/timing values, symbol names and token data.
Receipt stream hashes identify originals; use the explicit mapping for archive
members. K/M displays are rounded decimal units. A 99.964% request reduction
does not imply a matching retained-memory or peak-RSS improvement. Current
Linux x64/minimum Swift 6.2 and full benchmark/resource refresh remain pending.
