# Library-only documentation export correction

23 November 2026, following the initial M8 candidate `f499c4a` in PR #30.
The user requested a project-focused roadmap and continuation toward 1.0.
[Roadmap](https://github.com/kerker00/GMSetzer/blob/418882ff66357ce17e968d389b62d77296d665db/Docs/Roadmap.md) records the planned stages without links to other
parser projects.

## CI failure and correction

The initial minimum Swift 6.2 CI passes library/specification tests, optimized
builds and all 52 Python tests on macOS/Linux. Its separate documentation job
fails after all six libraries compile: package-wide symbol graph extraction
also tries to load the unbuilt `GMSetzerPackageTests` runner module.

The documentation script now builds only the umbrella library target and
emits symbol graphs during library compilation. Its six existing dependency
modules are built through their normal graph; test discovery/runner extraction
is not requested. Each run emits into a fresh temporary directory, validates
all six module files and only then replaces the generated graph directory.
Compilation failures, missing module files and malformed graphs remain errors.

Three regression tests cover the missing-test-runner scenario, stale previous
graphs concealing an incomplete current export, and a failed library build.
The CI API step and documented local commands now read `symbolgraph/` directly.

The first library-only CI attempt then rejects the optional compiler flag
`-symbol-graph-skip-synthesized-members`, which the local Swift 6.4 toolchain
accepts but Swift 6.2 does not. That unnecessary flag is removed; the regression
compiler model also rejects it. Source-owned API collection already excludes
unowned generated declarations, and all 610 candidate declarations remain
checked against the unchanged baseline. No compiler failure is ignored.

## API inventory representation

The compiler's direct emission omits the presentation-only `extension Profile`
grouping node that standalone extraction included. All 610 real declarations,
including the defining `Profile` and its GFM member, remain present. The
original 611-record baseline is unchanged. The checker normalises only empty-
conformance extension grouping nodes, not nominal types, members or recorded
conformances. Three regressions check equivalence and ensure that removing the
defining type or an extension member still fails compatibility.

The next CI run builds all six archives on Swift 6.2, then identifies nine
callback display signatures with omitted `@Sendable` annotations. Comparison
now accepts exactly this omission only with matching lexical tokens from the
actual complete source header. Three further regressions reject absent source
evidence, removed/moved annotations and an annotation occurring only in a body.
A local replay of all nine real declarations passes with the original baseline;
no signature, annotation or compatibility expectation is removed.

## Local verification

Swift 6.4.2 on the existing Mac builds all six DocC archives with warnings as
errors using the new library-only path. Both the original standalone-extraction
graphs and the new compile-time graphs pass the unchanged candidate API
inventory after representation normalisation. All 61 Python tests pass after
the source-backed annotation checks. Linux x64 independently passes the earlier
58-test correction and library graph/API compilation with Swift 6.4.2; DocC
is not installed on that host and no Linux DocC archive build is claimed.
No Swift runtime implementation, grammar, profile, fixture, API signature or
performance budget changes in this correction.

The completed follow-up passes all 61 Python checks and the 610-declaration
API check independently on Linux. At `cbdc977`, all three minimum-toolchain
CI jobs also pass: macOS Swift 6.2.3 / Linux Swift 6.2 library/spec/script and
optimized-build checks, plus six warning-free DocC archives and API validation.
The [retained follow-up receipt](roadmap-followup-2026-11-23/receipt.json)
records the exact run, source hashes and logs. Earlier failed runs remain
identified above rather than being relabelled as successful verification.
