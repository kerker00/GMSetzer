# M0 review — 19 November 2026

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

Scope: review the project, plan, library scaffold, specification harness,
fixture tooling and benchmark setup. Correct M0 and the plan without starting
M1. The existing `feature/m0-scaffold` branch is retained; no publication or
Setzkit source change is part of this review.

The module split, dependency-free Swift core, UTF-8 input and flat value tree
are a reasonable foundation. M0 remains a scaffold: the parser emits only a
document root, the renderer emits an empty string, and profiles only store a
name. Passing the baseline suite is not CommonMark or GFM conformance.

## Findings and corrections

| Priority | Finding | Correction |
| --- | --- | --- |
| High | `SpecTests` removed all examples marked `disabled`, which were exactly the two task list examples (279/280). A 670/670 target could therefore pass without task list support. | Run all 672 pinned examples. Add a corpus regression check for task lists and tag filtering; update the requirements and M4 gate. |
| High | Counting passes allowed a newly passing example to hide a regression in a previously passing example. | Store passing example IDs in `baseline.json` and require each recorded ID to remain passing. Test the equal-count swap explicitly. |
| High | M2 required 652/652 HTML comparisons, but the renderer and HTML normalisation were scheduled for M3. Even M1 block-section examples can require inline parsing. Safe defaults also disagree with spec output for raw HTML, comments and some URLs. | Grow basic rendering alongside M1/M2, complete conformance rendering/normalisation by M2, and use block AST/range tests for the M1 gate. Define explicit conformance settings and separate safe-renderer tests before M3 integration. |
| Medium | The GFM requirement omitted disallowed raw HTML; a safe renderer does not itself implement the GFM tag-filter extension. | Name tag filtering as a separately switchable GFM extension and test it even when raw HTML is explicitly enabled for conformance. See the [GFM specification](https://github.github.com/gfm/#disallowed-raw-html-extension-). |
| Medium | `update-specs.sh` downloaded mutable `master` into a file labelled 0.29. The baseline IDs and corpus could silently change. | Pin the matching Swift cmark fork revision and verify SHA-256 of both downloaded sources before replacing fixtures. Offline tests cover successful regeneration from another working directory and both checksum failures leaving existing fixtures intact. The stored spec fixtures are unchanged. |
| Medium | Benchmarks used CommonMark-only C without inline source-position tracking, compared with a positioned GMSetzer goal and swift-markdown's different default features. The reported commit was only a branch name. | Add matching C core/GFM and GMSetzer profile entries; enable `CMARK_OPT_SOURCEPOS`; register C extensions outside timed iterations. Describe swift-markdown as contextual. Preserve historical results with their limitations; fresh measurements remain pending. |
| Medium | `NodeKind` names and profile names alone do not supply semantic payloads, source segments, a cross-module builder or extension rule dispatch. Source-range requirements confused original syntax with decoded content. | Put these contracts first in M1, including tree validation, deterministic rule priority, original snapshot ranges, line endings, tabs and invalid-byte mapping. Keep renderer hooks outside parser dependencies. No speculative M1 API was implemented during review. |

## Evidence and remaining limits

- The [CommonMark 0.31.2 specification](https://spec.commonmark.org/0.31.2/)
  separates block and inline parsing. An HTML-based block-section acceptance
  gate cannot isolate those phases.
- The GFM fixture reproduces `test/spec.txt` from
  [swift-cmark revision 08ddb528923cc1a6527e02b7a1aee9e516ca749a](https://github.com/swiftlang/swift-cmark/blob/08ddb528923cc1a6527e02b7a1aee9e516ca749a/test/spec.txt).
  Its converted objects match the existing fixture exactly. Keep the
  distinction between this pinned corpus and the published GFM spec; classify
  differences against CommonMark 0.31.2 before M4.
- The locally pinned swift-markdown 0.9.0 converter attaches `table`,
  `strikethrough` and `tasklist`, without extended autolinks. The earlier
  description as complete GFM was too broad. MarkdownKit's
  [own limitations](https://github.com/objecthub/swift-markdownkit#known-issues)
  also distinguish those features. The plan now qualifies its candidate
  assessment and removes unmeasured JavaScript slowdown figures as evidence.
- The local Swift 6.4.2 SDK marks `UTF8Span` as Apple OS 26+, while `Span`
  has back-deployment support. Keep byte-buffer parsing available; the
  provisional deployment targets are unchanged. Swift 6.2 and Linux builds
  have not been verified here.
- Initial effort estimates remain estimates. Revisit them after M1; security,
  extension design and hardening are substantial work.
- Setzkit's product/architecture documents still refer to the older parser
  evaluation. Align them during integration; this review only edits GMSetzer.

## Validation

- Fresh scratch build with Swift 6.4.2: all five Swift Testing tests pass.
  The harness compares all 652 CommonMark and 672 GFM examples; current stub
  passes remain **1/652** and **2/672**, respectively. The protected examples
  have empty HTML output.
- Two offline Python test methods pass, including separate failure cases for
  changed CommonMark and GFM downloads. Shell syntax check passes.
- The modified `ParserBenchmarks` executable builds and its help command
  runs. No full benchmark run or new performance claim was made.
- Tests use scratch/cache directories under `/private/tmp` because the normal
  Swift compiler cache is outside the workspace sandbox. The library build
  itself requires no third-party dependencies.

The review stops at corrected M0. The next step is M1's source/model/extension
contract followed by block parsing, when the owner resumes implementation.
