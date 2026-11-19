# M1-B measurement protocol

Status: instrumentation prepared; measurements, phase budgets and acceptance
remain pending. This follows [Review-M1.md](Review-M1.md). A benchmark executable
that builds or lists successfully is not performance evidence.

## Cases and comparison scope

There are 30 cases: ten at each nominal size (100 KB, 1 MB, 5 MB). Every case
records its **actual UTF-8 byte count** and versioned corpus identity as tags.
The generator rounds up to complete blocks.

| Cases per size | Input | What is timed |
| --- | --- | --- |
| GMSetzer CommonMark / GFM parse | `mixed-v1`, original corpus unchanged | Parser construction, block parse and tree validation, with default syntax collection off |
| C CommonMark / GFM parse | Same `mixed-v1` bytes | Parser construction, `CMARK_OPT_SOURCEPOS`, corresponding extension configuration, parse and freeing; global extension registration is outside timing |
| swift-markdown parse | Same `mixed-v1` bytes | Context only: fixed upstream features and smart punctuation differ |
| GMSetzer validate | A pre-parsed `mixed-v1` tree | Public `Document` validation, including its existing segments/fallback metadata; excludes parsing |
| GMSetzer render | The same pre-parsed `mixed-v1` tree | Safe-default block HTML rendering; excludes parsing |
| GMSetzer reference syntax off / on | `references-v1` | Reuse a configured parser and vary only `collectSyntaxDetails`; includes parsing and validation |
| C references | Same `references-v1` bytes | Core parse/free with source positions; contextual reference for this focused workload |

All cases report wall-clock percentiles, total allocation count and gross
allocated bytes. Allocation backend/toolchain changes require a fresh baseline;
do not compare these counts blindly with a different Swift version/backend.
Gross allocated bytes are not retained heap size or peak RSS.

`references-v1` deliberately repeats multiline and nested reference definitions
to exercise annotation storage. Its labels repeat; C may discard duplicates
and does not retain GMSetzer's original-definition/provenance nodes. The
meaningful annotation overhead is the paired GMSetzer off/on comparison.

GMSetzer still lacks inline parsing and GFM implementations. A current ratio
below two does not establish equivalent completed work or final performance.
An exceeded total budget already in the block phase is a blocker. Annotation
collection here means reference component spans, not the future complete token
table, linting or Setzkit's UTF-16 decorations.

## Run and record

First commit the harness and verify that the checkout is clean. Record its
commit, `Tools/Package.resolved`, Swift version, macOS/kernel version, CPU and
RAM, relevant options and any diff. Close competing workloads; keep machine
power/thermal conditions consistent. The default maximum sampling duration is
five seconds per case, plus warmup and setup, so the full run takes minutes.

From the GMSetzer repository root:

```sh
swift package --package-path Tools benchmark list --target ParserBenchmarks
swift package --package-path Tools benchmark run --target ParserBenchmarks --format markdown --path /private/tmp/gmsetzer-m1-b-results --no-progress
```

Obtain the owner's authorization before the second command, as required by
`CLAUDE.md`. Build/list and ordinary tests do not execute the full measurement
suite. In the restricted workspace, redirect compiler/package caches and scratch
paths, disable sandboxed plugin execution, and use `-debug-info-format none` if
dSYM generation is unavailable. Release optimisation must remain enabled.

Keep the raw exports and add a measured entry to [Benchmarks.md](Benchmarks.md)
with p50 values, units, allocation metrics and the exact tagged byte counts.
Explain failures or unsupported metrics rather than replacing them with the
historical M0 numbers. Fixture creation and pre-parsed tree setup are outside
each measured closure; validation/render results are not end-to-end totals.

## Local acceptance gate

For each matching mixed-corpus size/profile, compare GMSetzer parse p50 with
the measured C p50 and the Mac absolute limit from Plan section 3. The allowed
total is the stricter of the absolute limit and twice the corresponding C time.
Record remaining headroom for inline work; report default and optional
annotation overhead separately. The unavailable GFM rules remain an explicit
gap, even if its current timing passes.

Keep public tree validation in release. Use its isolated timing/allocation
entry to decide whether dense visited storage or another checked construction
path is justified. Do not subtract independently measured medians and claim an
exact phase attribution; setup/cache effects differ. Repeat questionable
measurements before accepting a storage/dispatch redesign.

After a representative baseline exists, choose and document a local regression
tolerance and named comparison cases. Do not invent numeric phase budgets or
regression thresholds before the data, and do not add wall-clock assertions to
ordinary unit tests. No CI is enabled by this gate.
