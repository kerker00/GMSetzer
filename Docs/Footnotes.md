# M5 named footnotes

Merged in PR #20 (`a6a2da6`), based on `db077dd` after front matter
merged in PR #19. Not yet in a versioned release. This is a separate M5 step;
math, alerts and callouts remain open. No runtime dependency, new core node
case or change to strict CommonMark/GFM selections is introduced.

## Selection and presentation

```swift
import GMSetzer

let profile = Profile(name: "with-footnotes", extensions:
    [ExtensionConfiguration(Footnotes.identifier)])
let parser = try MarkdownParser(profile: profile,
    extensions: [Footnotes.implementation], collectSyntaxDetails: true).validated()
let document = parser.parse("Text[^note].\n\n[^note]: A *note*.\n")
let notes = Footnotes.Index(document).notes
// notes[0].number == 1
// notes[0].definition and notes[0].references are snapshot-bound node indices.
let html = FootnotesHTMLRenderer().render(document)
```

Both selecting `footnotes` and supplying `Footnotes.implementation` are
required. Append the selection to `Profile.gfm.extensions` to combine it with
GFM. `frontmatter` can be selected and supplied alongside it. Merely supplying
the implementation leaves strict profiles unchanged.

The parser implementation and `Footnotes.Index` live in `SetzerExtensions`.
`FootnotesHTMLRenderer` lives in the convenience module `GMSetzer`, composing
`SetzerHTML` and `SetzerExtensions` without adding a dependency between them.
Direct users of individual products choose their own rendering policy.

## Declared grammar and lookup

- A definition starts with `[^label]:`, preceded by zero to three indentation
  columns. It can interrupt a running paragraph. Up to four indentation
  columns after the colon are removed from the first content line; additional
  indentation remains available to Markdown, including indented code.
- Subsequent nonblank definition lines require four indentation columns,
  removed through the core's physical tab-stop projection. Blank lines are
  retained, allowing multiple paragraphs, lists, quotes and code. An
  unindented nonblank line ends the definition. **Lazy unindented continuation
  is deliberately outside this step.**
- Definitions can be empty and can occur in lists, quotes and nested
  definitions. Existing container boundaries and depth limits apply. Labels
  contain 1...999 Unicode scalars; ASCII controls/space, DEL and unescaped
  brackets are rejected. Backslash escapes of `[`, `]` and `\` are retained
  as part of the source-spelled label. Failed scans have a fixed byte bound.
- References use `[^label]` and resolve against definitions from the complete
  block tree, including forward definitions. Matching uses the existing
  locale-independent Unicode full case folding over raw label spelling, with
  byte-exact equality after folding. No canonical Unicode normalization,
  entity decoding or escape decoding is applied. The first matching
  definition in source order wins; duplicates remain in the tree.
- Only known labels become reference nodes. Unknown/malformed references
  continue through ordinary Markdown parsing without a footnote diagnostic.
  A known reference takes precedence over a following ordinary link target.
- Escaped opening brackets, code, raw HTML, consumed link destinations/titles
  and any open link/image bracket context remain protected. This conservative
  bracket policy also applies when an outer bracket ultimately remains
  unresolved. Pandoc inline `^[...]` notes are not supported.

The syntax starting points are
[GitHub's footnote documentation](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#footnotes)
and [micromark's documented footnote grammar](https://github.com/micromark/micromark-extension-gfm-footnote#syntax).
The explicit continuation and bracket policies above define this step; it is
not a claim of complete GitHub, Pandoc or micromark equivalence. Code and test
strings are original; no third-party implementation or fixture was copied.

## Tree, numbering and source

`footnotes.definition` is a custom block container with a raw `label` string
attribute and ordinary parsed Markdown children. `footnotes.reference` is a
custom inline leaf with the same raw label attribute. `Footnotes.label(node)`
returns that spelling for either kind. Definition ranges include their marker,
content and consumed line endings; child projections exclude the marker and
continuation prefixes without rebuilding source bytes. Reference ranges cover
the complete `[^label]` spelling. All offsets remain in `Document.source`.

`Footnotes.Index(document)` returns cited notes in display order, each with
`number`, winning `definition` index and `references` indices. Body references
assign numbers first. Then each cited definition body is visited once, in
assigned-note order, discovering further notes. Uncited definition bodies are
not searched for calls. Self references and cycles are finite; no node is
copied or recursively expanded for display. Repeated calls share a number and
receive distinct occurrence identifiers.

The post-inline `footnotes.number` transform stores the computed `number`
integer on cited definitions/references and `occurrence` integer on reachable
references. It preserves node indices, topology, tokens, fallbacks, diagnostics
and rendering policy. `Footnotes.Index` can also compute the same view when
that annotation transform is disabled. Indices/ranges are snapshot-bound;
consumers own revision identity and caches.

With collection enabled, definition and reference nodes own these tokens:

| Role | Exact spelling |
| --- | --- |
| `footnotes.definition.open` / `footnotes.reference.open` | `[^` |
| `footnotes.definition.label` / `footnotes.reference.label` | Original label bytes |
| `footnotes.definition.close` | `]:` |
| `footnotes.reference.close` | `]` |

Body syntax and enclosing quote/list marker tokens remain available. Annotation
off preserves identical nodes, numbering and HTML, with `tokens == nil`.
Disable rules independently through `Profile.disabledRules` using
`footnotes.definition`, `footnotes.reference` and `footnotes.number`.

## HTML and other services

`FootnotesHTMLRenderer(renderer:idPrefix:backlinkLabel:)` renders body calls as
numbered links, then appends a `section.footnotes` with an ordered list of cited
definitions and one backlink per reachable call. Unused and duplicate
definitions are omitted. The wrapper's own numeric IDs use a caller-selected
namespace; unsafe prefix bytes (including underscore) are hex-encoded without
collisions. `backlinkLabel` is plain text that callers may localise.

The supplied `HTMLRenderer` retains URL restrictions, raw-HTML/comment policy,
GFM tag filtering and hooks for other kinds, including front matter. Footnote
hooks are owned by this wrapper. Child block anchors/source attributes remain
those of the base renderer; the generated note wrappers use footnote IDs.
Contextual hooks reuse one `DocumentIndex` across body and note rendering.
All source text and generated attribute values are escaped as appropriate;
caller-returned hook HTML retains the existing trust boundary.

Plain `HTMLRenderer` retains its generic custom-node fallback: parsed children
or escaped source for a leaf. It does not group footnotes or hide unused notes.
Native analysis retains its existing opaque-custom-content policy, including
note bodies. The source-order outline retains its existing traversal through
custom block containers, so headings in notes appear there. Consumers may
filter that outline through `DocumentIndex` parent/ancestor queries.

## Supporting extension API

`InlineRule(..., prepare:)` builds a snapshot-specific matcher once after block
transforms and before inlines. Nested inline controllers reuse that prepared
matcher; a subsequent parse prepares a new one. Existing `match:` initializers
retain their behavior. Prepared matchers remain trusted `Sendable` callbacks.

`allowsBracketSyntax: true` explicitly enables complete custom matches at `[`
outside open link/image brackets. Existing rules default to false. Bracket
matches cannot open/close custom delimiter handles; invalid results retain
ordinary core parsing and report the existing runtime extension diagnostic.
Escapes/code/HTML/destinations stay protected. This is a deliberate additive
entry point, not a change to existing rules' dispatch.

`BlockContext.droppingBytes(_:from:)` removes a byte-counted, tab-free prefix,
including Unicode or invalid UTF-8, retaining original byte columns and line
endings. The rule chooses its syntax boundary; tabs use `droppingIndentation`.
The ASCII-only helper retains its old contract.

## Validation

Tests cover the declared grammar, empty/multiblock/nested definitions, first
definition and first call ordering, repeated calls/backlinks, missing labels,
Unicode/full folding and maximum label bounds, code/link/HTML exclusion,
BOM/CRLF/CR/invalid bytes/NUL, quoted/list projections, annotation parity,
rule switches, GFM/front-matter combinations, source-order outline and native
analysis policy, rendering safety/hooks, cyclic notes and depth limits.
Prepared-rule probes test once-per-snapshot preparation, parse reuse, explicit
bracket dispatch and rejection before mutation. An additional corpus test
checks supplied-but-unselected footnotes and composed rendering against all
1,324 existing specification examples without changing fixtures or baseline IDs.

Executed on 20 November 2026, based on `db077dd` plus this branch's changes:

| Environment | Commands/checks | Result |
| --- | --- | --- |
| macOS arm64, Xcode 27.2, Swift 6.4.2 | `swift test --disable-sandbox`; `swift build -c release --disable-sandbox` | 178 tests pass; release build passes |
| macOS arm64, Swift 6.2 | `swift test --disable-xctest --disable-sandbox` with extracted Swift 6.2, its Testing library and macOS 14.4 SDK | 178 tests pass |
| Existing Linux x86-64 host, kernel 7.3.4, Swift 6.4.2 | `swift test`; `swift build -c release` in an isolated source copy | 178 tests pass; release build passes |

macOS commands use task-specific scratch/cache/configuration/security and
module-cache paths outside the repository. Counts are 168 library tests and
10 specification tests: 21 footnote tests, three prepared-rule probes and one
corpus test added by this step. Every environment retains 652/652 CommonMark
and 672/672 GFM protected examples. No fixture or baseline ID changed.

PR CI passes on macOS and Linux with Swift 6.2, including the Python script
checks and both release builds. Merged-main CI also passes on both hosts. The merged branch is removed locally and remotely; no
additional worktrees existed. Unchanged Python scripts were not rerun locally.
No fresh reference-tool comparisons,
benchmark series or consumer UI/device checks were run; no performance claim,
consumer integration or versioned release is implied.
