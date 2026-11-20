# M5 functional acceptance

20 November 2026, merged `main` at `c9543fe` (PR #22), after front matter
(PR #19, `4b0f105`), footnotes (PR #20, `a6a2da6`) and math (PR #21, `6f166b7`).
The plan's M5 criterion is that declared extension fixtures and profile/
combination tests pass. That functional criterion is met by the merged tree
and executed checks below. This is not M6 performance/hardening acceptance
or approval to publish a version tag.

## Requirement and evidence

| M5 scope | Implemented contract and checks |
| --- | --- |
| YAML/TOML front matter | [FrontMatter](FrontMatter.md): original-document start, opaque raw text/bytes, exact ranges/tokens, independent formats and safe caller-controlled output; 17 dedicated tests |
| Named footnotes | [Footnotes](Footnotes.md): definition/reference lookup, multiblock bodies, first-definition/call ordering, repeated backlinks, finite cyclic-note handling and independent rules; 21 dedicated tests |
| Inline/display/fenced math | [Math](Math.md): opaque TeX, exact provenance, dollar guards, projected display blocks and core math-code-fence conversion; 23 dedicated tests |
| Alerts and callouts | [Admonitions](Admonitions.md): five alert types, parsed custom titles, callout styles/folding, nested containers, header/setext/table boundaries and remapped annotation owners; 23 dedicated tests |
| Strict CommonMark and GFM profiles | All 652 CommonMark and 672 GFM protected examples pass. Four all-example supplied-but-unselected checks compare nodes/tokens/diagnostics and exact/composed HTML. Profiles are not implicitly expanded |
| Independent selection and combinations | Per-form/rule switches, annotation on/off, GFM combinations and the all-M5 title/body case in `AdmonitionTests.allM5FeaturesComposeIncludingMathAndFootnoteCallsInTheTitle` pass |
| Portable source/renderer boundary | BOM, Unicode, CRLF/CR, malformed UTF-8/NUL, source owners, escaped fallback/hooks and URL policy have dedicated checks; typed facades and optional composed HTML stay in their documented modules |

## Executed merged-main CI

[Run 44822884457](https://github.com/kerker00/GMSetzer/actions/runs/44822884457)
checks the exact merged commit `c9543fe5ecc792a765ee709637197c07aee9a634`.
Both jobs completed successfully:

| Environment | Executed checks |
| --- | --- |
| macOS 26, Xcode 26.2, Apple Swift 6.2.3 | 227 Swift tests (27 suites), 652/652 CommonMark, 672/672 GFM, optimized library build, 17 offline Python tests |
| Ubuntu 24.04, Swift 6.2 | 227 Swift tests (27 suites), both complete protected corpora, optimized library build, 17 offline Python tests |

The local Swift 6.4.2/macOS, extracted Swift 6.2/macOS and existing Linux-host
checks for the final implementation are recorded in [Admonitions](Admonitions.md).
Those results are historical implementation evidence, not a fresh post-merge
run. Comparing `v0.4.0..c9543fe` confirms no changes to `Package.swift`, the
protected baseline or the pinned CommonMark/GFM JSON fixtures. Runtime sources
retain their standard-library/package-only imports; no Foundation or app UI
framework import was added.

## Declared limits and next work

The feature documents define the accepted grammar. This acceptance does not
claim full GitHub/Pandoc/Obsidian equivalence. Front matter is raw, not YAML/TOML
deserialisation; footnotes require explicit continuation indentation; inline
math stays on one physical line and needs a caller TeX engine; admonition HTML
supplies structure without an application theme. Existing generic outline,
plain-text and native-analysis custom-content policies remain explicit.

M6 still owns fresh selected-extension timing/allocation measurements, broader
hostile-input/fuzzing work and speed targets. No new benchmark/reference series
was run for this acceptance. Consumer editor/device integration and minimum
Apple runtime verification remain separate. The source-only
[v0.5.0 preview](https://github.com/kerker00/GMSetzer/releases/tag/v0.5.0) is now
published at `2d8ecef`, following preparation PR #23, owner confirmation and
successful tag-triggered CI. Exact-version SwiftPM consumption and source-only
publication evidence are in [release validation](Validation/Release/0.5.0.md).
Publication does not complete M6 or consumer runtime acceptance.
