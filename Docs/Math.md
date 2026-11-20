# M5 opaque TeX syntax

Implemented on `feature/m5-math`, based on `ae3ca76` after footnotes merged in
PR #20. Not yet merged or released. This step recognises inline, dollar-display
and fenced math. Alerts and callouts remain open. It adds no runtime dependency,
core node case or TeX engine; presentation belongs to the caller.

## Selection and typed access

```swift
import GMSetzer

let profile = Profile(name: "with-math", extensions:
    [ExtensionConfiguration(Math.identifier)])
let parser = try MarkdownParser(profile: profile,
    extensions: [Math.implementation], collectSyntaxDetails: true).validated()
let document = parser.parse("Text $x_1$.\n\n$$\nx^2 + y^2\n$$\n")
let expressions = document.nodes.indices.compactMap { Math(document, at: $0) }
// expressions[0].format == .inline; expressions[0].tex == "x_1"
// expressions[1].format == .display; expressions[1].isDisplay == true
```

Both selecting `math` and supplying `Math.implementation` are required.
`Profile.commonMark` and `Profile.gfm` remain unchanged. Append the selection to
`Profile.gfm.extensions` for GFM combinations; front matter and footnotes can
be selected and supplied alongside math. Disable forms independently with
`math.inline`, `math.display` and `math.fenced` in `Profile.disabledRules`.

`Math(document, at:)` returns a `Hashable`/`Sendable` value containing `format`
(`.inline`, `.display`, `.fenced`), `isDisplay`, complete `range`, original
`contentRanges`, owned `rawBytes` and projected `tex`. Invalid indices, other
kinds/roles, children and malformed payload shapes return nil. Indices and
offsets belong to this snapshot; consumers own revision identity and caches.

## Declared grammar

### Inline dollars

Single `$` delimiters surround nonempty TeX on one physical line. An opener
must not be followed by Unicode whitespace. A closer must not follow Unicode
whitespace or precede an ASCII digit. Backslash-escaped dollars do not delimit;
even/odd backslash parity matters. Delimiters must be runs of exactly one
dollar; longer runs are not separate single-dollar delimiters. Thus ordinary
`$20,000 and $30,000` stays prose. TeX contents are opaque: Markdown emphasis,
code, links, entities and escapes inside an accepted span are not interpreted.

Core escapes, code spans, raw HTML and consumed link destinations/titles stay
protected. Math may appear inside emphasis and link/image labels, using the
existing inline controller. A prepared next-close lookup is built once per
snapshot; each opener is indexed independently, so a dollar in consumed code
cannot steal later pairs. Matches additionally require one contiguous original
source range inside the current projected inline input, preventing cross-cell
or cross-leaf consumption. Failed candidates remain ordinary Markdown without
an extension diagnostic. Selecting a custom trigger can split adjacent text
nodes even when no math matches; unchanged literal cases preserve exact HTML
and source, not necessarily the strict parser's text-node grouping.

The spacing/currency starting point is
[Pandoc's dollar-math rules](https://pandoc.org/MANUAL.html#extension-tex_math_dollars).
This step deliberately excludes multiline single-dollar math and GitHub's
alternative dollar/backtick syntax; it does not claim dialect equivalence.

### Dollar display blocks

A display opener starts a line after zero to three indentation columns and
may interrupt a paragraph. Supported forms are:

```text
$$ x^2 + y^2 $$

$$
\begin{aligned}
x &= y
\end{aligned}
$$
```

The one-line form has distinct, exact-width `$$` fences; its closing fence
ends the line apart from ASCII spaces/tabs and must be unescaped. Interior
whitespace is retained. In the multiline form, opening and closing lines
contain only `$$` plus optional ASCII spaces/tabs after indentation. The first
matching closing line ends the block, including at EOF. Blank interior lines
and empty bodies are allowed. Content removes up to the opener's indentation,
using the existing physical-tab projection; enclosing quote/list prefixes
remain excluded. A closing fence is required. Unclosed/wrong-width forms fall
back to ordinary Markdown without swallowing input or adding a diagnostic.
Paragraph-internal `text $$x$$` is outside this block grammar.

### Math code fences

Existing CommonMark backtick/tilde fences are recognised by the core first.
The post-inline `math.fenced` transform converts code blocks whose decoded
first info word is exactly, case-sensitively `math`. Further info words are
permitted. Fence length, indentation, container boundaries, empty blocks and
unclosed-EOF behavior remain those of core code fences. Other languages stay
ordinary code. Unlike dollar blocks, unclosed math code fences are accepted
through EOF, including the core's synthetic final LF in the semantic literal.

[GitHub's mathematical-expression documentation](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/writing-mathematical-expressions)
is the reference for dollar-display and `math`-fence authoring forms. Grammar
details above are this implementation's declared scope. Code/tests are original;
no external implementation or fixture was copied.

## Tree and source contract

`math.inline` is a custom inline leaf; `math.block` is a custom block leaf.
Both carry string attributes `format` and `tex`, have no Markdown children
and do not validate TeX commands, syntax or macros. `tex` retains TeX spelling
without Markdown entity/escape decoding, normalizes block line endings to LF
and replacement-decodes invalid UTF-8/NUL. Math code fences use the existing
core code literal, including virtual indentation and EOF normalization.

`rawBytes` concatenates only the original `contentRanges`: original CRLF/CR,
Unicode, invalid UTF-8 and NUL remain available. It is provenance rather than
a reconstructed semantic string: a partially consumed tab retains its source
byte, while `tex` contains the projected spaces. An empty block retains an
empty insertion range. Complete block ranges include delimiters and consumed
line endings/indentation; a leading BOM stays in `Document.source` outside
syntax. Inline node segments cover the whole match; the typed view derives
their delimiter-free content range. Block segments cover content only.

With syntax collection enabled, the expression owns `math.fence.open`,
`math.content` and `math.fence.close` tokens. Multiline blocks have one content
token per source segment; empty content has an empty token. Fenced math retains
existing `core.fence.*` tokens verbatim and adds namespaced aliases, including
`math.fence.info`. An unclosed code fence has no closing token. Token emission
order is not a source-sort contract. Annotation off yields the same nodes,
expressions, fallbacks and HTML, with `tokens == nil`.

## Rendering and other services

The caller uses `Math.inlineKind` / `Math.blockKind` hooks to pass `tex` and
`isDisplay` into a separately chosen TeX engine. This package does not evaluate
TeX, produce MathML, install JavaScript or load external resources. For an
escaped-text presentation, for example:

```swift
let hook: ContextualHTMLRendererHook = { context in
    guard let math = Math(context.tree.document, at: context.index) else { return nil }
    let tag = math.isDisplay ? "div" : "span"
    return .replace("<\(tag) class=\"tex\">\(HTMLRenderer.escape(math.tex))</\(tag)>")
}
let html = HTMLRenderer(contextualHooks:
    [Math.inlineKind: hook, Math.blockKind: hook]).render(document)
```

This example displays escaped TeX text, not typeset formulas. Caller-produced
hook HTML retains the existing trust boundary. Default rendering escapes
custom leaves even with `allowRawHTML: true`: inline and dollar-block fallbacks
retain projected delimiter spelling; converted code fences use their semantic
code literal. Generic outline/plain-text/image-alt and native-analysis handling
keep the existing custom-leaf policies; math contents do not become headings,
references, lint findings or fixes. Image-alt text requires a caller image hook
if it should include a custom math leaf. Math hooks compose with front-matter
hooks and `FootnotesHTMLRenderer` through its base renderer.

## Validation

`MathTests` covers all three forms, exact source/tokens/owners, currency and
Unicode whitespace, escaping/parity, core-protected contexts, opaque TeX,
display indentation/container boundaries, empty/unclosed/EOF behavior, decoded
fence languages, mode disabling, annotations on/off, BOM/CRLF/CR/invalid bytes/
NUL, typed views, hook escaping, analysis/outline and GFM/front-matter/footnote
combinations. Large unmatched-input cases are functional checks, not timing
measurements. An additional corpus test checks all 1,324 existing examples
with math supplied but unselected; fixtures and protected IDs are unchanged.

Executed on 20 November 2026, based on `ae3ca76` plus this branch's changes:

| Environment | Commands/checks | Result |
| --- | --- | --- |
| macOS arm64, Xcode 27.2, Swift 6.4.2 | `swift test --disable-sandbox`; `swift build -c release --disable-sandbox` | 202 tests pass; release build passes |
| macOS arm64, Swift 6.2 | `swift test --disable-xctest --disable-sandbox` with extracted Swift 6.2, its Testing library and macOS 14.4 SDK | 202 tests pass |
| Existing Linux x86-64 host, kernel 7.3.4, Swift 6.4.2 | `swift test`; `swift build -c release` in an isolated source copy | 202 tests pass; release build passes |

macOS commands use task-specific scratch/cache/configuration/security and
module-cache paths outside the repository. Counts are 191 library tests and
11 specification tests: 23 math tests and one corpus test added by this step.
Each environment retains 652/652 CommonMark and 672/672 GFM protected examples.
No fixture or protected ID was changed. Minimum-version macOS/Linux PR CI is
still pending; unchanged Python scripts were not rerun locally.

Development identity is `0.5.0-dev.3`, not a release tag. No fresh benchmark
or reference-tool series, consumer TeX-engine integration, UI or device checks
were run; these results imply no typesetting or performance claim.
