# M4 GitHub Flavored Markdown

20 November 2026. Implementation on `feature/m4-gfm`, based on M3
([PR #12](https://github.com/kerker00/GMSetzer/pull/12), `651af17`). Review,
full test matrix and owner merge are open.

## Owner decisions

- **Built-in payloads (1A).** Tables, task list items and strikethrough are
  typed `NodeData` cases implemented by the core parser, not custom kinds of
  the extension API. Consumers read a table's alignments or a checkbox state
  directly; no attribute dictionaries are allocated per cell. The extension API
  is exercised by the M5 features instead.
- **GitHub's nested strong (2A).** cmark-gfm builds the CommonMark tree and
  omits the tags of a strong node whose parent is strong only when rendering
  HTML. GMSetzer does the same: the tree stays CommonMark 0.31.2; the GFM
  profile selects a rendering policy. This yields the nine GFM 0.29 emphasis
  examples without a second emphasis algorithm.

## Profile and switches

`Profile.gfm` selects six built-in identifiers (`BuiltinExtension`). Each can
be selected alone or combined; no implementation is supplied by the caller,
and supplying one with the same identifier is a configuration issue.

| Identifier | Effect |
| --- | --- |
| `gfm.table` | `table(TableAttributes)`, `tableRow(isHeader:)`, `tableCell(alignment:)` |
| `gfm.tasklist` | `taskListItem(checked:)` in place of `listItem` |
| `gfm.strikethrough` | `strikethrough` inline (one or two tildes) |
| `gfm.autolink` | `link` nodes for www, http(s)/ftp URLs, email, `mailto:` and `xmpp:` |
| `gfm.tagfilter` | Rendering policy `filtersDisallowedRawHTML` |
| `gfm.collapseNestedStrong` | Rendering policy `collapsesNestedStrong` |

Rendering policies live in `Document.renderingPolicy`, set by the parser from
the profile and applied by `HTMLRenderer`. They change output only. The tag
filter acts when raw HTML is emitted (`allowRawHTML`); safe default rendering
escapes raw HTML anyway. Extended autolinks are ordinary links: under safe
rendering an `ftp:` destination is blank unless `allowedURLSchemes` contains
`.ftp`.

## Recognition (ported from cmark-gfm)

The rules are ported from cmark-gfm's extensions as pinned in swift-cmark
`08ddb528` (BSD-2; see NOTICE) onto GMSetzer's byte and line model:

- **Tables.** A delimiter row (`[|]? marker ([|] marker)* [|]?`, marker
  `:?-+:?`) on a fully matched paragraph continuation line, at most three
  columns indented, after every other block start failed, turns the paragraph's
  last line into a header with the same cell count. A paragraph that fails this
  check is never rechecked. Rows continue until a blank line, a lazy line, any
  other block start (including indented code and HTML type 7) or a line that is
  not a row. Short rows are completed with empty, unaligned cells; extra cells
  are dropped. A pipe after a backslash belongs to its cell; that backslash is
  removed from the cell text. cmark-gfm's limit of 0x80000 completed cells
  applies.
- **Lines before a table header** become a paragraph exactly as cmark-gfm
  inserts it: reference definitions in it remain text and `\|` loses its
  backslash. GitHub renders the same.
- **Task lists.** The physical line must match
  `spacechar* (-|+|*|digits any) spacechar+ [ ]|[x]|[X] spacechar+`, with the
  checkbox at the content start of the item opened on that line. Items inside
  block quotes therefore stay plain, as on GitHub. The rest of the line is
  always paragraph text.
- **Strikethrough.** Runs of at most two tildes (scanned up to 100) flank like
  `*`, using cmark-gfm's Unicode P-category punctuation. Equal openers and
  closers wrap; unequal ones remain text.
- **Autolinks.** www and URL matches run at `w` and `:` outside open brackets,
  with cmark-gfm's domain, underscore, trailing-punctuation, parenthesis and
  entity trimming rules. Email, `mailto:` and `xmpp:` matches run after the
  leaf over consecutive decoded text outside links, so `a\@b.cd` links like in
  cmark-gfm. Links keep exact source ranges; a boundary inside an escape or
  entity snaps to its start.
- **Tag filter.** `<` of `title`, `textarea`, `style`, `xmp`, `iframe`,
  `noembed`, `noframes`, `script` and `plaintext` (case-insensitive, followed by
  whitespace, `>` or `/>`) becomes `&lt;` in emitted raw HTML.

## Source ranges and syntax tokens

Rows span their line; cells span the raw bytes between pipes; a cell's text
segments exclude escaping backslashes and trimmed whitespace. With
`collectSyntaxDetails`, the parser records `gfm.table.delimiterRow`,
`gfm.table.pipe`, `gfm.tasklist.marker`, `gfm.strikethrough.open/close` and
`gfm.autolink` tokens. Analysis, outline and traversal descend into task list
items like list items; tables contain no headings.

## Conformance and validation

- **Specification corpus.** The pinned GFM 0.29 corpus is defined per example,
  as upstream's spec runner does: core examples run without extensions, an
  extension example with exactly its extension (`disabled` means the task
  list), always with GitHub's nested-strong rendering. All **672/672** pass and
  are protected; CommonMark stays **652/652**.
- **Reference comparison.** `Tools/Tests/ContainerReferenceTests/GFMReferenceTests`
  compares `Profile.gfm` with cmark-gfm and all five extensions on documents
  generated from 88 GFM fragments (pairs, random sequences and CRLF variants).
  A local probe over 41,649 such documents and over all 1,324 specification
  inputs with every extension on agreed except for the cases below.
- **Known reference differences, all CommonMark core:** CommonMark 0.31.2
  examples 28 (invalid numeric references) and 354 (currency symbols as
  punctuation) differ from cmark-gfm's 0.29 core; and after a backslash hard
  break, cmark-gfm keeps the indentation of a lazy continuation line, which
  CommonMark removes. GMSetzer follows CommonMark 0.31.2 there.
- **CommonMark unchanged.** The M3 differential probe (2,958 documents:
  positions, caret queries, trees, outline, HTML, analysis) is byte-identical
  to `275a69b` for the CommonMark profile.
- **Tests.** New `GFMTests` cover switches, ranges, tokens, validation and
  rendering policy. The full library suite, the Tools reference tests,
  Swift 6.2 and Linux have not yet been run for this branch.

## Performance

Local release probe, Apple M2, 1 MB mixed corpus, median of 31 parses; not a
package-benchmark run. CommonMark parses in 24.2–24.8 ms against 23.7–24.4 ms
on `main` (within 1–2 %). GFM parses in 28.4 ms; the corpus now produces 1,825
real tables with 10,950 cells, about 20,000 more nodes than before. During
implementation, moving table state out of the open leaf, counting rows without
allocation and skipping email scans of runs without `@` reduced GFM from
37.5 ms. Official measurements and the budget gate are pending.
