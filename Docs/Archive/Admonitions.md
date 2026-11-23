# M5 alerts and callouts

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

Merged in PR #22 (`c9543fe`), based on `3a12ff1` after math merged in PR #21.
Included in the v0.5.0 preview. This implements the remaining declared M5
syntax; [functional acceptance](M5Acceptance.md) is complete.
No runtime dependency, core node case or module dependency is added.

## Selection and HTML

```swift
import GMSetzer

let profile = Profile(name: "gfm-with-admonitions", extensions:
    Profile.gfm.extensions + [ExtensionConfiguration(Alert.identifier),
                             ExtensionConfiguration(Callout.identifier)])
let parser = try MarkdownParser(profile: profile,
    extensions: [Alert.implementation, Callout.implementation],
    collectSyntaxDetails: true).validated()
let document = parser.parse("> [!NOTE]\n> An alert.\n\n> [!tip]- A **title**\n> A callout.\n")
let html = AdmonitionHTML.renderer().render(document)
```

Selection and registration are both required. Strict `Profile.commonMark` and
`Profile.gfm` remain unchanged. Each implementation can be selected alone.
When both match `> [!NOTE]`, normal block-rule priority/profile order decides;
put alerts first to prefer the stricter alert form. Explicit `ruleOrder` can
override this with `alerts.recognise` / `callouts.recognise`. Folded/titled
headers and other types belong to callouts regardless of default selection
order. The wrapping transforms operate only on their own recognised headers.

Disable a syntax using `alerts.recognise` or `callouts.recognise` in
`Profile.disabledRules`; its wrapping pass then has nothing to convert.
`alerts.wrap` / `callouts.wrap` are separately disableable transform phases:
disabling only wrapping deliberately retains an internal header leaf with
escaped literal fallback inside the ordinary quote.

## Declared grammar

The marker must start the first physical line of a newly opened core quote,
after its prefix and zero to three indentation columns. A blank initial quote
line, a preceding paragraph, code/HTML context or escaped marker is not a
header. Core quote/list continuation, nesting and depth limits still apply.

- Alerts accept exactly `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` and
  `[!CAUTION]`, followed only by ASCII spaces/tabs. The marker has its own line;
  body blocks start on following lines. Empty alerts are allowed.
- Callouts accept a case-insensitive ASCII type with letters, digits, `_` or
  `-`, including at least one alphanumeric byte. An optional adjacent `+`
  expands by default; `-` collapses. An optional title follows ASCII space/tab
  separation. Trailing ASCII spaces/tabs are removed from the title. A custom
  title is parsed as inline Markdown independently of the body; title-only
  callouts are allowed. Without a title, the normalised type supplies a title.
- Nested callouts and quotes in lists are supported. Body paragraphs, lists,
  tables, code, headings and thematic breaks are parsed normally. A dedicated
  header block prevents a following underline/table delimiter from consuming
  the marker as a heading or table header. There is no Markdown reconstruction
  or second parse of body text.
- Obsidian's built-in style names and aliases are mapped to canonical styles.
  Examples: `summary`/`tldr` → `abstract`, `hint`/`important` → `tip`, `faq`/`help`
  → `question`, `caution`/`attention` → `warning`, `error` → `danger` and `cite`
  → `quote`. Unknown names keep their type but use the `note` fallback style.

Syntax references are [GitHub's alert documentation](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)
and [Obsidian's callout documentation](https://help.obsidian.md/callouts).
This library also recognises alerts within existing quote/list containers;
GitHub's site documents a narrower nesting policy. No complete site/theme,
Obsidian wikilink/embed/plugin or CSS compatibility is claimed. Implementation
and test strings are original; no external code or fixtures were copied.

## Tree and typed views

`Alert` and `Callout` are `Hashable`/`Sendable` snapshot views constructed with
`(document, at: nodeIndex)`. Invalid indices, other kinds or malformed typed
payload shapes return nil. `Alert` provides `category` and full quote `range`;
`Alert.Category` supplies the five names and English `defaultTitle` strings.
`Callout` provides normalised `type`, canonical `style`, `fold` (`.none`,
`.expanded`, `.collapsed`), `title`, `hasCustomTitle`, optional `titleNode`
and full `range`. A custom `title` is source-spelled Markdown with replacement
decoding for malformed UTF-8/NUL; original bytes remain in `Document.source`.

Final custom block containers are `alerts.block` and `callouts.block`, with
the original quote range and ordinary body children. Their string attributes
are `type`, plus callout `fold` and optional custom `title`. A custom callout
title is the first child, a `callouts.title` block containing one paragraph
whose inlines are parsed by the normal controller. It retains the exact title
range/segment. Generated titles have no invented source node. Empty wrappers
retain an explicit empty fallback, avoiding phantom marker text/paragraphs.

Recognition first emits an internal `alerts.header` / `callouts.header` leaf
on the marker line. Before inlines, the owning wrapping transform rebuilds
the quote as its custom container and removes the header. Node indices may
change. Consumers must use the returned snapshot rather than retaining node
indices across transforms or revisions.

## Syntax provenance and transform validation

Header tokens use the owning `alerts.` / `callouts.` namespace:

| Suffix | Exact range |
| --- | --- |
| `marker.open` | `[!` |
| `type` | Original type spelling/case |
| `marker.close` | `]` |
| `fold` (callouts) | Adjacent `+` or `-`, when present |
| `title` (callouts) | Custom title before inline decoding, when present |

Final ownership is the resulting wrapper. Existing core quote/list, body,
title-inline and foreign extension tokens retain role/range and remap to
validated owners. Original BOM/Unicode/CRLF/CR/invalid bytes/NUL remain in
source. Collection off produces identical nodes, fallbacks and HTML with
`tokens == nil`.

`BlockContext.isBlockQuoteStart` identifies a newly opened immediate core
quote on its first physical line with no children. Rules still check their
grammar/indentation; a projected marker alone does not open a core quote.
The signal does not change existing rule selection or precedence.

Tree-rebuilding transforms may remap foreign token owners. The controller
checks a multiset of foreign `(role, range)` spellings: ownership may change
within validated node ranges, but new foreign spellings or extra copies are
rejected before replacing the previous snapshot. Own-namespace tokens remain
extension-controlled. Source identity, collection mode, namespace and tree
validation still apply; callbacks retain their existing compiled-code trust
boundary.

## Rendering and other services

On the initial M6 branch, `AdmonitionHTML.renderer` certifies its built-in
hooks as independent for [prepared HTML groups](ProgressiveHTML.md). A custom
base hook still requires an explicit `HTMLHookBehavior.independent` promise;
otherwise composition keeps the documented whole-document fallback. Existing
full-string rendering and complete-document title/footnote context are unchanged.

`AdmonitionHTML.renderer(base, alertTitles:calloutTitles:)` lives in the
`GMSetzer` convenience product. It returns an ordinary `HTMLRenderer` with
contextual hooks. Alerts use `<aside>` plus a generated title. Plain callouts
use `<aside>`; foldable callouts use `<details>` and a first `<summary>`, with
`open` only for `+`. Classes/data attributes expose type/style; no stylesheet,
icons, script or external resource is installed. Title dictionaries localise
generated plain-text titles; custom title Markdown retains normal parsing.

The base renderer's URL/raw-HTML/comment policy, GFM tag filter, source anchors
and other hooks remain active. Custom title rendering uses the current composed
renderer and shared tree index, so math hooks and numbered footnote calls work
inside titles as well as bodies. For footnotes, use
`FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(base))`. Title source
containers are suppressed after their inlines have rendered in the title.
Source text and generated attributes are escaped; caller-returned HTML retains
the existing hook trust boundary. Hand-built invalid typed payloads fall back
to normal rendering.

Plain `HTMLRenderer` retains its custom-container fallback and displays children
without admonition wrappers/generated titles/folding. Native analysis treats
custom bodies as opaque; the source-order outline still includes body headings.
Library tests do not establish app themes, native disclosure controls, editor
colours or device acceptance.

## Validation

Tests cover both grammars, type/style aliases, title-only/empty/nested cases,
folding, marker placement/indentation/partial tabs, normal body blocks, the
setext/table boundary, selection/disable/precedence, exact tokens/remapped
owners, annotation parity, BOM/Unicode/CRLF/CR/invalid bytes/NUL, safety and
localised titles/source anchors, outline/analysis and all-M5 combinations.
Separate transform probes permit valid owner remapping while rejecting foreign
token forgery/duplication. An all-example supplied-but-unselected check protects
all 1,324 specification trees/tokens/diagnostics and composed conformance HTML.

Executed on 20 November 2026, based on `3a12ff1` plus this branch's changes:

| Environment | Commands/checks | Result |
| --- | --- | --- |
| macOS arm64, Xcode 27.2, Swift 6.4.2 | `swift test --disable-sandbox`; `swift build -c release --disable-sandbox` | 227 tests pass; release build passes |
| macOS arm64, Swift 6.2 | `swift test --disable-xctest --disable-sandbox` with extracted Swift 6.2, its Testing library and macOS 14.4 SDK | 227 tests pass |
| Existing Linux x86-64 host, kernel 7.3.4, Swift 6.4.2 | `swift test`; `swift build -c release` in an isolated source copy | 227 tests pass; release build passes |

macOS commands use task-specific scratch/cache/configuration/security and
module-cache paths outside the repository. Counts are 215 library tests and
12 specification tests: 23 admonition tests, one transform probe and one corpus
test added by this step. Each environment retains 652/652 CommonMark and
672/672 GFM protected examples. No fixture, baseline ID or manifest changed.
PR and merged-main CI pass on macOS/Swift 6.2.3 and Linux/Swift 6.2, including
17 script tests and optimized builds per host. The merged branch is removed
locally and remotely; no additional worktrees existed. Unchanged Python
scripts were not rerun locally. Development identity is `0.5.0-dev.4`, not a release tag.
No fresh benchmark/reference series or consumer UI/device checks were run.
