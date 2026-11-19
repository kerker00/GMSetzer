# M1 review — 19 November 2026

Scope: architecture, code, quality assurance and extensibility of the merged M1
state (`main` at `7d4c8a5`, library code identical to `2132a15`), measured
against [Plan.md](Plan.md), [EditorAnalysis.md](EditorAnalysis.md) and
Setzkit's parser, pipeline and extension requirements. This review records
findings and recommendations only; no library code was changed.

## Summary

The foundation is sound: a dependency-free module split, typed payloads from
which node kinds derive, a flat `Sendable` value tree, byte ranges into the
original snapshot with source segments, iterative traversal, and a regression
baseline per specification example. Three areas need decisions **before M2**,
because the inline phase would otherwise be built on structures that later
have to change:

1. **Performance:** the block phase alone already exceeds the speed budget.
2. **Extension architecture:** only custom leaf blocks are possible, and
   built-in syntax uses a separate path from extensions.
3. **Block parser structure:** the main loop needs to be decomposed before
   inline parsing and more extension hooks are added.

## Evidence

- `swift build` succeeds with Swift 6.4.2 on Apple Silicon (macOS 27).
- The test suite was **not** run for this review.
- A throw-away probe executable in a scratch package (release build, local path
  dependency) reproduced the findings marked *confirmed* below and produced the
  informal timings in the next table. These are not package-benchmark results
  and do not replace [Benchmarks.md](Benchmarks.md).

| Informal measurement, 1 MB, release, best of 5 | Result |
| --- | --- |
| Parse, block phase only, mixed document (headings, paragraphs, lists, quotes, fenced code) | 66 ms |
| `Document(source:nodes:)` validation of the same tree alone | 25 ms |
| Parse, plain paragraphs only | 20 ms |
| Render the mixed document | 31 ms |
| Plan limit: 2 × cmark-gfm (historical 19 ms, without source positions) | ≤ 38 ms |
| Plan absolute target, Mac | < 60 ms |

## Architecture findings

| Priority | Finding | Recommendation |
| --- | --- | --- |
| High | **Speed budget already exceeded without inline parsing.** About a third of parse time is the full validation that `DocumentBuilder.build()` runs on the parser's own output. Further likely costs: one `String` per text node and one `[SourceRange]` allocation per node. | Set the budget per phase now and add a measurement gate. Validate parser-built trees only in debug builds or with a bitset instead of `Set<Int>`. Evaluate shared segment storage and lazily decoded literals before M2 fixes the inline payloads. |
| High | **No parent links and no position query.** Setzkit's breadcrumb and folding need "node at offset X and its ancestors". With only `firstChild`/`nextSibling` this is a scan of the whole tree. | Add a parent index array to `Document` and a node-at-offset query with the M3 outline work; the storage decision belongs in M2. |
| Medium | **Syntax spans grow per payload.** `ReferenceSyntax` is a dedicated structure for one node kind. Repeating that pattern for every inline payload makes the model sprawl, while callers such as Quick Look should not pay for spans at all. | Introduce one optional, generic token table in `Document` (role, range, owning node) before M2. It also serves EditorAnalysis syntax roles and extension syntax. |
| Medium | **Configuration problems are reported as document diagnostics.** Missing or duplicate extensions appear in every parsed `Document` at range `0..<0`. EditorAnalysis requires configuration failures to stay separate from document findings. | Resolve the registry once in `MarkdownParser.init` and report configuration problems there, for example through a throwing or validating initializer. |
| Medium | **`try!` in the parser.** `BlockParser.append` and `parse()` trap on builder errors. This is probably unreachable today, but any future validation gap would crash the host, including a Quick Look extension. | Return a document with a diagnostic as fallback instead of trapping, or prove unreachability with targeted tests. |
| Medium | **UTF-8 byte order mark not handled (confirmed).** `"\u{FEFF}# Title"` renders as `<p>﻿# Title</p>`. Setzkit preserves existing BOMs, so such files occur in practice. | Skip a leading BOM in block parsing while keeping source offsets unchanged; add a regression test. |

## Extensibility findings

The only extension point today is a custom leaf-block rule. It covers display
math and front matter, but not the rest of the 1.0 scope.

| Required feature | Needs | Possible today |
| --- | --- | --- |
| `$$` math blocks, front matter | Leaf block rule | yes |
| Footnote definitions | Container block with parsed children | no |
| Alerts, Obsidian callouts | Post-processing, splitting the first text node | no |
| Inline math, strikethrough, `==highlight==`, wikilinks | Inline triggers with delimiter-stack access | no |
| GFM tables | Access to the running paragraph's lines | no |
| GFM task lists | List item attributes | no |
| Syntax roles for extension syntax | Spans emitted by the extension | no |

| Priority | Finding | Recommendation |
| --- | --- | --- |
| High | **Two classes of syntax.** Built-in constructs are hard-wired in the main loop; extension rules run on a side path before them. An extension or profile cannot disable or replace a built-in construct, which future profiles need (for example Pandoc without indented code, or a profile without HTML blocks). | Register built-in block (and later inline) rules in the same registry as extensions, in the style of markdown-it rule chains. This is cheap before M2 and expensive afterwards. |
| High | **Inline extension API undefined.** M2 will implement the delimiter stack; extensions for `$`, `~~`, `==` and `[[` need access to it. | Design the inline rule API before implementing the inline parser and implement core inlines through it. Sketch alerts, footnotes and inline math against the draft API as acceptance checks. |
| Medium | **An extension is not one unit.** Parser rules and renderer hooks are registered separately and linked only by strings. | Declare an extension's identifier, version, node kinds and option schema in one descriptor in `SetzerSyntax`; parser and renderer parts stay in their modules, preserving the dependency rules. |
| Medium | **No namespace ownership.** Two extensions can emit the same custom kind; rule identifiers are unique only within one extension. | Require custom kinds and rule identifiers to start with the extension identifier; report violations as configuration errors. |
| Medium | **Options are not validated.** A misspelled option has no effect and no diagnostic. Setzkit requires unknown rules and options to be reported. | Validate options against the declared schema when the parser is configured. |
| Medium | **Extensions cannot report diagnostics or produce children.** `BlockMatch` yields exactly one childless node; parsed Markdown content can only be carried as attribute strings. | Extend the match result with child content ranges parsed by the core, and a diagnostic channel for extensions. |
| Medium | **Renderer hooks lose context (confirmed).** A `.list` hook returning `wrapChildren` turns a tight list into a loose one with `<p>` tags, because tightness is passed only through internal render events. | Give hooks a context value with tightness and ancestors; test hooks on every built-in container. |
| Low | **Unknown custom leaves inside containers render prefixes (confirmed).** A two-line custom leaf in a block quote renders `:::\n&gt; body`, because the renderer escapes the whole node range instead of its source segments. | Render the source segments, or the content lines projected through container prefixes. |
| Note | **Trust model fits Setzkit.** Setzkit plans compiled-in, typed catalogs and no third-party runtime plugins. GMSetzer needs a good compiled Swift API, not sandboxing or runtime budgets. | Keep callbacks documented as trusted code. |

## Code findings

| Priority | Finding | Recommendation |
| --- | --- | --- |
| Medium | `BlockParser.parse()` in `ContainerParsing.swift` is a 160-line loop with state flags, `continue` jumps and force-unwrapped `leaf!`. | Split it into the cmark phases before M2: match open containers, continue the open leaf, open new containers, start a leaf. |
| Low | ASCII bytes appear as decimal literals (`35`, `60`, `96`, …) throughout. | Use named constants such as `UInt8(ascii: "#")` in one `ASCII` namespace; this also helps extension authors. |
| Low | Punctuation classification and NUL replacement are duplicated between `BlockParser` and `ReferenceScanner`; array literals are used for membership tests in hot paths. | Share small byte-classification helpers. |
| Low | The renderer re-scans HTML block literals to remove comments. | Let the parser record comment ranges once. |
| Low | `SourceRange.init` traps on invalid bounds, so an extension constructing a bad range crashes the host. | Document the precondition for extension authors, or offer a failable initializer. |

## Quality assurance findings

Strengths: the per-ID baseline, revision-pinned and checksum-verified spec
sources, cmark reference comparison over almost 2,000 documents, and tests for
invalid extension results are above the usual standard at this stage.

| Priority | Finding | Recommendation |
| --- | --- | --- |
| High | No fuzzing, no pathological cases with time limits, no performance gate. The current speed regression is not detected by any test. | Add pathological fixtures with time limits and a benchmark threshold check before M2. |
| Medium | Neither Linux nor the minimum Swift 6.2 toolchain has been built (open questions in the plan). | Verify both before the inline phase adds more code at risk. |
| Medium | All three confirmed defects sit in feature combinations: hooks with lists, extension nodes in containers, BOM with block starts. | Add combination tests per extension point and container kind. |
| Low | No invariant tests relate decoded literals to their source segments. | Add an invariant check over all spec examples: each text literal must be reproducible from its segments under the documented decoding rules. |

## Process and documentation

- PRs #2 and #3 are merged, but the local `main` was stale and branch cleanup
  had not run when this review started.
- Setzkit's `Setzkit-Markdown-Parser.md` still lists PR #2 as open, uses the
  old working target names and cites 670 instead of 672 GFM examples.
- Status lines are repeated in README, Plan, SyntaxTree and the Setzkit
  document and are already drifting. The README module table lists outline
  queries and position conversion as module contents although both are planned.

## Recommended order before M2

1. Define the speed budget per phase with a gate; move validation out of the
   hot path.
2. Decide the extension architecture: one registry for built-ins and
   extensions, an extension descriptor, the inline rule API, container and
   post-processing hooks. Validate the draft with alerts, footnotes and inline
   math.
3. Introduce the token table and the parent index array.
4. Fix the three confirmed defects with regression tests.
5. Decompose the block parser main loop.
