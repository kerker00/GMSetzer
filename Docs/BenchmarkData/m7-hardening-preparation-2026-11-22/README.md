# M7 hardening preparation evidence

22 November 2026, macOS arm64 / Apple Swift 6.4.2. See the
[report](../../Validation/M7/hardening-preparation-2026-11-22.md) and
[workload/reproduction contract](https://github.com/kerker00/GMSetzer/blob/418882ff66357ce17e968d389b62d77296d665db/Docs/M7HardeningWorkloads.md).

- `receipt.json`: final five-case smoke receipt, source/executable hashes,
  compiler/load, Git revision and dirty state. This tools-only change is
  measured over `a56a26e`; the uncommitted harness is identified by hashes.
- `cases.txt`: all 69 new tagged identities, listed without parsing inputs.
- `historical-cases.txt`: all 72 historical identities, equal to the prior list.
- `smoke.csv`: final p50 timings and allocation displays; preserve unit labels.
- `validation.json`: executed checks and hashes of the six harness/test files.
- `logs.tar.gz`: 38 sanitized streams/receipts from the failed filter attempt,
  first corrected smoke, final stricter-validation smoke and tests/listing.
- `artifacts.json`: archive hash and each original/sanitized member hash.

Host names, local checkout/home paths and process addresses are redacted in
retained streams. Raw case-log hashes in receipts refer to original streams;
use the explicit original-to-retained mapping for archived content. Allocation
figures are gross counts/volume, with rounded K/M displays; they are not live
heap or peak RSS. Only the five final cases appear in `smoke.csv`; the earlier
successful run is preserved as history, without a speedup comparison. The
initial failed filter attempt has no result rows. No full matrix is executed.
