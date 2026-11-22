# M7 inline capacity evidence

22 November 2026. See the [report](../../Validation/M7/inline-capacity-2026-11-22.md).
Three runtime files and two regression methods over `3fdc646`; measured
uncommitted source is identified explicitly, without a clean-commit claim.

- `before.receipt.json`, `after.receipt.json`, `summary.csv`, `comparison.json`:
  matched 30-case subsets per variant (12 hardening + 18 mixed), original
  allocation labels, timings, hashes and host load. No full 69/72 refresh.
- `allocation-before.json`, `allocation-after.json`, `allocation-summary.json`:
  separate full stack recording; counts/volume per iteration, not timing/RSS.
- `layout.json`: compiled internal item/bracket and public-node strides.
- `c-absolute.json`, `m2-*.json`, `budgets.json`: six plus nine passing checks
  using unchanged inputs and limits.
- `candidate-source.json`, `change.patch.gz`: measured source/test hashes and
  exact patch, with context whitespace retained inside gzip.
- `linux-source.json`, `linux-validation.json`: 78 transferred file hashes and
  native ARM64 Debug/Release results. Connection/key details are excluded.
- `public-equivalence.json`: identical 1,324 public tables with 7,994 nodes and
  4,422 tokens; the complete snapshots/probe are archived.
- `validation.json`: executed checks and pending gates; no fresh Python suite
  is claimed for unchanged scripts.
- `logs.tar.gz`: 45 complete sanitized streams, profiles, probes and snapshots.
  `artifacts.json` maps original/retained digests and hashes the archive.
- `sha256.json`: hashes retained data files, excluding itself.

Redaction replaces host/home/checkout names and process addresses, retaining
numerical values, symbols and public tree data. Raw receipt hashes identify
original streams; the explicit mapping identifies retained archive members.
K/M displays are rounded decimal units. Gross byte traffic falls 31.21% in the
profiled bracket case; this does not establish peak RSS or retained heap, and
conservative capacity hints can reserve unused slots. Probe serialization and
internal stride measurements do not define new public API/ABI contracts.
