# M5 first step: raw YAML and TOML front matter

Merged in PR #19 (`4b0f105`), based on `3abbcc8` after PR #18.
Not yet in a versioned release. `FrontMatter` is a real `MarkdownExtension` in
`SetzerExtensions`, using the existing custom-block API. There is no new core
node case, runtime dependency or YAML/TOML deserialiser. Footnotes, math,
alerts and callouts remain separate M5 work.

## Selection and typed access

```swift
import GMSetzer

let profile = Profile(name: "gfm-with-frontmatter", extensions:
    Profile.gfm.extensions + [ExtensionConfiguration(FrontMatter.identifier)])
let parser = try MarkdownParser(profile: profile,
    extensions: [FrontMatter.implementation], collectSyntaxDetails: true).validated()
let document = parser.parse("---\ntitle: Example\n---\n# Body\n")
let metadata = document.root.firstChild.flatMap { FrontMatter(document, at: $0) }
// metadata?.format == .yaml
// metadata?.rawText == "title: Example\n"
```

Both selecting `frontmatter` and supplying `FrontMatter.implementation` are
required. Merely registering it does not change parsing. `Profile.commonMark`
and `Profile.gfm` retain their strict existing selections. Disable each format
through `Profile.disabledRules` with qualified IDs `frontmatter.yaml` and
`frontmatter.toml`; disabling both restores ordinary Markdown recognition.

`FrontMatter(document, at:)` provides `format` (`.yaml` / `.toml`), complete
block `range`, `contentRange`, owned `rawBytes` and computed `rawText` in a
`Hashable`/`Sendable` value. Wrong indices, other nodes and malformed custom
payload shapes return nil. Offsets belong to the supplied snapshot; consumers
still own revision identity and caching.

## Fence grammar

- Open on the original first physical line, at column zero, optionally after
  one UTF-8 BOM. No preceding blank line or indentation is accepted. Quotes,
  lists and projected extension children cannot restart this recognition.
- YAML uses exactly `---` on both fence lines; TOML uses exactly `+++`.
  Only ASCII spaces/tabs may follow the three markers. The closing delimiter
  is also at column zero and may end at EOF without a line ending. LF, CRLF
  and CR are supported.
- The first matching closing fence ends the block. A closing fence is
  required; dangling/mismatched fences leave all input to ordinary Markdown
  parsing without an extension diagnostic. Empty metadata is valid.
- Interior data is opaque. Invalid YAML/TOML is still front matter, and
  serialization string quoting does not change markup fence recognition.
  No fields, values, references or document settings are interpreted.
- JSON, YAML `...` closing delimiters and configurable alternative fences
  are outside this first step. Later front-matter-looking blocks are normal
  Markdown.

Behavior references are [Hugo's delimiter examples](https://gohugo.io/content-management/front-matter/)
and [remark's frontmatter syntax extension](https://github.com/remarkjs/remark-frontmatter).
This is not a claim of complete compatibility with those systems/serializers.

## Source and extension contract

The node is `.custom(kind: FrontMatter.kind, role: .block, ...)`, with kind
`frontmatter.block`, attribute `format: .string("yaml" / "toml")`, no children
and exactly one source segment covering only the original interior. Empty
metadata retains an empty insertion segment. The node range includes both
fence lines and the closing line ending; it excludes a leading BOM, which
remains in `Document.source`.

`contentRange` starts after the opening line ending and ends at the beginning
of the closing line. Raw bytes, line endings, Unicode, NUL and invalid UTF-8
remain available without normalisation. `rawText` uses Swift replacement
decoding for invalid UTF-8 while preserving valid NUL and line endings. This
is separate from the core's normalized safe fallback.

With collection enabled, three tokens share the metadata node owner:

| Role | Range |
| --- | --- |
| `frontmatter.fence.open` | Exactly the three opening marker bytes |
| `frontmatter.content` | Complete original interior, including an empty insertion range |
| `frontmatter.fence.close` | Exactly the three closing marker bytes |

Collection off keeps identical metadata/body and `tokens == nil`.
`BlockContext.isDocumentStart` is true only on the original first line before
containers open, and false in projected child parsers. Rules still validate
exact indentation/spelling. A wrapper projecting the original first line
without removing bytes cannot accidentally restart front matter.

## Rendering and other services

Rendering remains a caller policy. The generic fallback displays escaped
metadata including fences; even `allowRawHTML: true` does not execute it as
HTML. To omit front matter from output:

```swift
let renderer = HTMLRenderer(hooks: [FrontMatter.kind: { _, _ in .replace("") }])
let html = renderer.render(document)
// <h1>Body</h1>\n
```

The extension does not depend on `SetzerHTML`. A caller can instead use the
raw metadata to select a template and supply its own hook. Analysis and
outline see an opaque leaf: metadata does not become Markdown headings,
link-reference definitions, lint findings or fixes. Body Markdown and GFM
features continue normally.

## Validation

`FrontMatterTests` covers both formats, opt-in/per-format disabling, strict
start/fence grammar, dangling/mismatched closure, empty content, all line
endings, BOM/Unicode/NUL/invalid UTF-8, token ownership, GFM combinations,
analysis/reference/outline opacity, render fallback/hooks, projected wrappers,
typed-view validation and large unclosed input.

`SpecTests.unselectedFrontMatterImplementationPreservesEverySpecification`
checks all 1,324 existing examples with the implementation supplied but not
selected: complete nodes, tokens, diagnostics and exact HTML remain unchanged.
No fixture or protected ID is changed. Development identity is `0.5.0-dev.1`,
not a published tag.

Executed on 20 November 2026, based on `3abbcc8` plus this branch's changes:

| Environment | Checks | Result |
| --- | --- | --- |
| macOS arm64, Swift 6.4.2 | `swift test --disable-sandbox`; `swift build -c release --disable-sandbox` | 153 tests pass; release build passes |
| macOS arm64, Swift 6.2 | `swift test --disable-xctest --disable-sandbox` with the extracted Swift 6.2 toolchain, its Testing library and the macOS 14.4 SDK | 153 tests pass |
| Existing Linux x86-64 host, kernel 7.3.4, Swift 6.4.2 | `swift test`; `swift build -c release` in an isolated source copy | 153 tests pass; release build passes |

macOS commands use task-specific scratch, cache, configuration, security and
module-cache paths outside the repository. Counts are 144 library tests and
nine specification tests (18 tests added by this step). Each environment
retains 652/652 CommonMark and 672/672 GFM examples, including all protected
IDs. The additional unselected-extension check compares all 1,324 examples.

PR CI passes on Linux/Swift 6.2; macOS CI and merged-main CI are still
pending at this documentation update. The merged branch is removed locally
and remotely. Python scripts are unchanged and were not rerun locally. No new
reference-tool comparisons, benchmark series or consumer UI/device checks
were run; these results imply no fresh performance claim or consumer adoption.
