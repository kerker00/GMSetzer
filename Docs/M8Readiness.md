# M8 / 1.0 preparation

23 November 2026. The owner requested moving GMSetzer toward a stable 1.0 and
Swift Package Index publication. PR #30 merged the reviewed technical candidate
into `main` at `5f81308`, following PR #29 (`49afec9`). Merged-main CI run
45131801793 passes macOS/Linux and DocC/API checks. The owner requested release
preparation after confirming the merge. The development
identity is `1.0.0-dev.1`; the latest published preview remains 0.6.0.

## Implemented and checked

- [Proposed compatibility contract](APIStability.md) and a candidate API
  inventory, checked independently on Mac and Linux x64. The original 611
  export records include one presentation-only extension block; normalised
  checks retain all 610 actual declarations without rewriting the baseline.
- A small validated `MarkdownHTML` facade over existing parser configuration,
  with selected footnote/admonition composition and seven regression tests.
- DocC catalogs for all six products, with installation, extension selection,
  HTML safety, progressive output, editor integration and compatibility guides.
  All six archives build with warnings treated as errors.
- `.spi.yml` with all six documentation targets, and local documentation/API
  check scripts. Minimum-toolchain CI now enforces both successfully;
  release checks reject mismatched development identities or draft note titles.
- Swift 6.4.2 Mac/Linux Debug/Release suites pass 263 tests per configuration
  and both complete protected corpora. The follow-up passes 61 Python checks
  independently on Mac/Linux. Minimum Swift 6.2 CI at `cbdc977` also passes all
  263 Swift tests, 61 Python checks and optimized builds on both hosts, plus
  all six DocC archives and the 610-declaration API check.
- A separate local Release consumer imports only `GMSetzer` and exercises
  convenience HTML, GFM, outlines, positions, public tree traversal and identity.
  Release cross-builds pass for arm64 iOS 18 and visionOS 2; no device runtime
  or minimum-Swift execution is inferred from those cross-builds.

The [self-review](Review-M8.md) records decisions, corrections and the validation
boundary; [execution evidence](Validation/M8/2026-11-23/receipt.json) retains
source identities, logs and checksums; the [roadmap/CI follow-up](Validation/M8/roadmap-followup-2026-11-23/receipt.json)
retains current verification. Existing performance/resource evidence stays linked to its measured
M7 source; no new performance acceptance is inferred for the facade.

## Before a stable release

| Gate | Current state |
| --- | --- |
| Review/merge M8 changes | Complete: PR #30 merged at `5f81308`; merged-main CI passes |
| Accept M7 and proposed 1.x contracts | Final owner acceptance pending |
| Minimum Swift 6.2 CI, including DocC/API checks | All three jobs pass at `cbdc977`: macOS, Linux and DocC/API. Exact run/logs are retained in the follow-up receipt |
| Final documentation review | Every source-owned public type/typealias now has a summary; consequential defaults, preconditions and ownership are clarified, with a public tree-query guide. Final owner review of guides/remaining individual member summaries pending |
| Exact merged release identity and notes | [Draft 1.0 notes](Releases/1.0.0.md) prepared; final commit/identity not chosen |
| Independent exact-version consumer and source archives | Required after confirmed tag; no 1.0 tag exists |
| Swift Package Index submission | Configuration ready; no submission sent |

SPI itself does not require version 1.0: an existing public SemVer preview can
already qualify. The stable-release contract is our own gate. Follow
[Releasing](Releasing.md#swift-package-index-and-10-preparation) for the verified
Index requirements and publication sequence. No intermediate 0.7 tag is a
technical prerequisite for 1.0 or for indexing.
