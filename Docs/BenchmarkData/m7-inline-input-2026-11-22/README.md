# Inline-input follow-up evidence

See the [report](../../Validation/M7/inline-input-2026-11-22.md) for results,
comparison contracts, source identities and limits. Runtime/test bytes of the
corrected candidate B match `f2e0a0e`; `7bb4560` changes only the optional HTML
verifier, its regression and documentation. Native transfers have no Git data.

| Data | Scope |
| --- | --- |
| `mac-before` | Original frozen PR #28 binaries; 18 ordinary baseline rows |
| `mac-parser-b`, `mac-m5-b` | Corrected B: 72 ordinary Mac rows and eight focused M5 rows |
| `repeat-before`, `repeat-after` | Retained 13-case Mac countermeasurement after control drift / anomalous footnote rows |
| `profile-before`, `profile-b` | Separate 1 MB allocation stacks, six before / seven B iterations; instrumented times excluded |
| `native/parser-before`, `native/parser-after` | Complete same-input x64 72-case pair; preserve C-control drift rather than treating it as code improvement |
| `native/native-repeat-after`, `native/native-repeat-before` | Reverse-order nine-case control repeat; persistent C CommonMark anomaly remains unexplained |
| `native/hardening-after`, `native/utf8-after` | Complete 69 / 36 current-source rows using direct built targets |
| `native/resource-after` | Five byte-identical wrapper/digest artifacts containing all 756 raw records; 42 cases / 126 checks pass |
| `native/parser-comparison` | 24 cases / 192 batch samples, 12 HTML comparisons and raw inputs/outputs for four parsers |
| `native/external` | Pinned GCC/Rust build receipts, dependency licenses, crate VCS identity and retained MIT license |
| `checks` | B source identities, runtime/test patch, Mac validation, minimum-compiler CI, budget checks and exact temporary orchestration helpers |
| `preparation/candidate-a` | Rejected unrestricted reuse variant; never substitute its timings/tests for B |

`checks/retention-before-fix` is an expected failure of candidate A after adding
the capacity assertion. `checks/retention-original` passes that assertion on
the original runtime. `checks/oracle-before` passes the three original focused
tests before any runtime optimization. B's complete tests include the new
capacity check. Earlier A test/mutation passes predate that check and are kept
as preparation only.

The additional-parser internal timers exclude the allocation interposer and
must not be combined with package-benchmark rows. Parsed callbacks/offset
events do not retain the AST/source services of GMSetzer. Raw HTML retains
renderer formatting differences; the verifier's narrow structural rules and
their tests are versioned in the repository. An initial formatting-only
preflight failure and its successful correction are separate directories.

The before binaries are validated against the preceding HTML-copy source and
binary receipts before freezing. Sources/executables are checked again after
ordinary runs. The original and corrected 72-case readers are retained because
the initial strict reader rejects valid zero-allocation ancillary probes;
postprocessing recovers original rows without changing/rerunning the export.
Native hardening uses the same built target directly because the regular
metadata runner requires a Git checkout. Its failed setup remains retained.
The initial native 151-file compilation manifest predates two Python verifier/
test corrections; the measured packet records those exact changes separately.
Runtime/test hashes remain equal to `f2e0a0e`. The 43-runtime / 5-resource-tool
inventory independently matches the current checkout.

Exact commands are in receipts/phase logs. Timed runs use `-O`/WMO, direct built
BenchmarkTool invocations and unchanged package pins/corpora/profiles. No own
build/test/profiler competes with ordinary timing on a measured host. Other
owner activity, power/temperature and sequential-pair ordering remain
uncontrolled. These records establish neither all-input complexity nor a
general memory/C-parity guarantee.

Text logs/Markdown/patches are gzip compressed with line endings preserved.
Task/home paths become labelled placeholders; retained Python helpers need
those task-specific paths replaced before replay. `archive-sha256.json` records
original-to-retained digests; `sha256.json` covers all retained files except
itself. Raw source-hash manifests identify actual transferred/measured sources,
not an invented clean native checkout. No build binaries or credentials are
committed. Resource wrapper artifacts are retained byte-for-byte so their
original digest contract remains valid. Check them from the package root:

```sh
python3 -I Scripts/check_progressive_html_budget.py \
  Docs/BenchmarkData/m7-inline-input-2026-11-22/native/resource-after \
  --source-root "$PWD" --include-measurement-tools
```
