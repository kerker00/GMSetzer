# M8 / 1.0 preparation

23 November 2026. The owner requested moving GMSetzer toward a stable 1.0 and
Swift Package Index publication. Preparation is implemented locally on
`feature/m8-api-docs`, based on merged PR #29 (`49afec9`). The development
identity is `1.0.0-dev.1`; the latest published preview remains 0.6.0.

## Implemented and checked

- [Proposed compatibility contract](APIStability.md) and a 611-declaration
  candidate API inventory, checked independently on Mac and Linux x64.
- A small validated `MarkdownHTML` facade over existing parser configuration,
  with selected footnote/admonition composition and seven regression tests.
- DocC catalogs for all six products, with installation, extension selection,
  HTML safety, progressive output, editor integration and compatibility guides.
  All six archives build with warnings treated as errors.
- `.spi.yml` with all six documentation targets, and local documentation/API
  check scripts. CI is prepared to enforce both on the minimum Swift toolchain;
  release checks reject mismatched development identities or draft note titles.
- Current Swift 6.4.2 Mac/Linux Debug/Release suites: 263 tests per configuration,
  both complete protected spec corpora, and 52 Python tests per host.
- A separate local Release consumer imports only `GMSetzer` and exercises
  convenience HTML, GFM, outlines, positions and the development identity.
  Release cross-builds pass for arm64 iOS 18 and visionOS 2; no device runtime
  or minimum-Swift execution is inferred from those cross-builds.

The [self-review](Review-M8.md) records decisions, corrections and the validation
boundary; [execution evidence](Validation/M8/2026-11-23/receipt.json) retains
source identities, logs and checksums. Existing performance/resource evidence stays linked to its measured
M7 source; no new performance acceptance is inferred for the facade.

## Before a stable release

| Gate | Current state |
| --- | --- |
| Review/merge M8 changes | Local candidate; owner review/merge pending |
| Accept M7 and proposed 1.x contracts | Final owner acceptance pending |
| Minimum Swift 6.2 CI, including DocC/API checks | Workflow updated; new-source CI run pending |
| Final documentation review | Generated pages and guides build; per-member editorial pass still required |
| Exact merged release identity and notes | [Draft 1.0 notes](Releases/1.0.0.md) prepared; final commit/identity not chosen |
| Independent exact-version consumer and source archives | Required after confirmed tag; no 1.0 tag exists |
| Swift Package Index submission | Configuration ready; no submission sent |

SPI itself does not require version 1.0: an existing public SemVer preview can
already qualify. The stable-release contract is our own gate. Follow
[Releasing](Releasing.md#swift-package-index-and-10-preparation) for the verified
Index requirements and publication sequence. No intermediate 0.7 tag is a
technical prerequisite for 1.0 or for indexing.
