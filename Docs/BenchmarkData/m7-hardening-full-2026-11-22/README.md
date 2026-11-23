# M7 full extension/hostile-input series

22 November 2026. All 69 cases complete at clean commit `2f5f1bd` on
macOS arm64 / Apple Swift 6.4.2, in 326 seconds. See the
[report](../../Validation/M7/hardening-scaling-2026-11-22.md) and
[workload contract](../../Archive/M7HardeningWorkloads.md).

- `receipt.json`, `cases.txt`: exact execution/source/binary/allocator identity
  and all 69 tagged names. Receipt case-log hashes identify original streams.
- `summary.csv`: all 69 p50 times, samples and original allocation unit labels,
  plus approximate count/byte conversions from rounded displays.
- `scaling.csv`: 23 groups with actual-byte and timing/allocation endpoint ratios.
- `annotation.csv`: 27 off/on pairs; `c-controls.csv`: 15 informational C pairs.
- `analysis.json`: the same derived comparisons and formula description.
- `analyse.py`: standalone standard-library table derivation; use normal
  isolated Python, as shown below (its consistency assertions are required).
- `logs.tar.gz`: all 142 per-case/list/receipt/name streams, sanitized only
  for local host/home/checkout names and process addresses.
- `artifacts.json`: archive hash and original-to-sanitized member hashes.
- `validation.json`: identity checks, actual scope and checks not repeated.
- `sha256.json`: hashes of retained data files, excluding itself.

Reproduce the tables from retained streams, using fresh temporary directories:

```sh
mkdir /private/tmp/gmsetzer-hardening-retained
tar -xzf Docs/BenchmarkData/m7-hardening-full-2026-11-22/logs.tar.gz \
  -C /private/tmp/gmsetzer-hardening-retained
python3 -I Docs/BenchmarkData/m7-hardening-full-2026-11-22/analyse.py \
  /private/tmp/gmsetzer-hardening-retained \
  /private/tmp/gmsetzer-hardening-derived \
  Docs/BenchmarkData/m7-hardening-full-2026-11-22/artifacts.json
```

Raw-log digests are checked against the original receipt; sanitized streams
must match the explicit mapping. These derivations reproduce exactly all five
retained CSV/JSON analysis files. Allocation units are decimal K/M; rounded
display conversions are approximate gross requests/volume, not retained heap
or peak RSS. C quote/invalid-byte policies differ, and M5 has no corresponding
C profile. This observational run supplies no new acceptance budget or proof
of linear complexity. Source, inputs, pins and limits are unchanged.
