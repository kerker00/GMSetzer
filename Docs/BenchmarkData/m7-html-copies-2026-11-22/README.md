# M7 HTML-copy evidence

See the [report](../../Validation/M7/html-copies-2026-11-22.md) for results,
source identity and limits. Measurements use the recorded uncommitted patch
over `0d660f9`; `candidate-source.json` hashes the changed runtime/test files.
The before executable hashes trace to the retained earlier M7 receipts.

`before-timing` / `after-timing` contain the first Mac pair; `control-before` /
`control-after` retain the focused repeat prompted by control drift. `native`
retains x64 validation and the complete 18-case pair. `profile-render-before` /
`profile-render-after` contain separate allocation stack exports; their timings
are excluded. All successful receipts check source/binary stability. Frozen
countermeasure receipts distinguish workspace hashes from old binary sources.

Preparation uses pinned dependencies and the explicitly selected native build
system after the retained default-system debug-symbol failure:

```sh
swift package --package-path Tools --build-system native -debug-info-format none \
  --scratch-path "$BENCH_BUILD" --skip-update --force-resolved-versions \
  benchmark list --target ParserBenchmarks --target HardeningBenchmarks \
  --target UTF8Benchmarks
```

The retained `measure.py` and `countermeasure.py` run direct Release benchmark
executables from the package root, with an output label and executable-directory
argument. Use separate directories for frozen before and rebuilt after binaries;
do not substitute a fresh build for the frozen baseline. Receipts record exact
filters, commands, bounds and hashes. Do not run tests/builds/profilers alongside
the ordinary timing processes.

`resource-after` preserves the fresh 42-case matrix's four-artifact digests and
756 raw records byte-for-byte. Check it from the package root with:

```sh
python3 -I Scripts/check_progressive_html_budget.py \
  Docs/BenchmarkData/m7-html-copies-2026-11-22/resource-after \
  --source-root "$PWD" --include-measurement-tools
```

`checks` includes Mac suites and bounded ASan mutation evidence; `native`
includes executed x64 phases. Text logs replace home/task paths and are gzip
compressed to preserve original line endings without Git whitespace changes.
`archive-sha256.json` records original-to-retained transformations;
`sha256.json` covers every retained file except itself. No build binaries or
credentials are included. Earlier unrelated validation is not relabelled as a
check of this renderer. Minimum-toolchain CI is recorded in the report when
available.
