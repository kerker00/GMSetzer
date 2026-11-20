# M2 CommonMark inlines and portable findings

20 November 2026. Functional implementation on `feature/m2-inlines`, based on
`main` at `34cbe31` (PR #10). M1 acceptance was merged in PR #9 (`61fcb95`).
**M2 merged in [PR #11](https://github.com/kerker00/GMSetzer/pull/11), merge commit `021f110`.** No publication or Setzkit integration is implied.

## Parsing and tree

The pipeline is blocks → pre-inline transforms → inline controller →
post-inline transforms. Leaf input is projected from the original text/line-end
nodes, retaining source pieces across quote/list prefixes. References are
collected document-wide before inline resolution, with first-definition wins,
Unicode full case folding and collapse of ASCII spaces/tabs/line endings in labels. Labels retain their
source spelling for matching; destination/title values decode escapes/entities.

Implemented built-in payloads are `code`, `emphasis`, `strong`, `link`, `image`,
`htmlInline` and `hardBreak`, in addition to decoded `text` and `softBreak`.
All remain immutable `Sendable` values in the validated flat tree. The core
uses index-based, iterative delimiter/bracket lists, flanking/rule-of-three
checks and openers-bottom search bounds. Code-span backtick runs are indexed
once; unmatched runs do not rescan the entire leaf. Residual delimiter text is
materialized once, rather than copying each shrinking run. Rendering is also
iterative, including image-alt traversal.

Plain inline leaves reuse their block-phase text. The inline controller also
reuses its item/delimiter/bracket storage across leaves within one parse,
clearing all handles, backtick caches and failure state between leaves. Other leaves decode ordinary
text by slices, avoid a temporary segment allocation for one-piece ranges and
keep syntax token storage disabled unless requested. Intermediate and final
Documents still run release validation. The three inline-phase `try!` sites
only use root/prior builder handles and controller-validated projected ranges;
invalid callbacks cannot supply topology or bypass final validation. Custom callback child projections use
a separate conservative recursion limit (16 by default, maximum 32), require a
strictly smaller child range and retain literal content at overflow. This fixes
a reproduced stack overflow in the initial recursive callback probe; built-in
CommonMark nesting does not use that recursive path.

Additional review regressions cover CommonMark's precise Unicode whitespace
class, autolinks deactivating surrounding links, minimal 0.31.2 HTML declarations,
16,384 declined custom triggers without repeated suffix scans, and cross-leaf
controller-state isolation. Custom-run ends are cached even when callbacks
return nil; built-in delimiter runs remain iterative. Empty positions after
CRLF map after both original bytes, including in nested child projections.
Reference-definition precedence uses original offsets, independent of flat
array storage order after a valid transform.

The remaining final CommonMark mismatch was a block bug: indentation beyond
four columns on internal blank code lines must survive. The code scanner now
uses the same indentation removal on blank/nonblank content lines; leading and
trailing blank-code policy remains covered by the existing tests. The old M1
heading test that expected an undecoded `\#` now expects the decoded `#`.

## Inline extensions

Public `InlineRule`/`InlineContext`/`InlineMatch` and opaque `DelimiterHandle`
replace the internal M1 draft. Protected core syntax runs before custom
triggers; deterministic trigger precedence uses profile order, priority and
explicit `ruleOrder`. Callback input offsets address the projected UTF-8 input,
with `originalRanges(for:)` for exact source coordinates. Owned kinds/tokens,
progress, child containment and delimiter handle/flanking/width/scope are
checked before mutation. Partial custom delimiter-run consumption is rejected.
Handles retained across parses or from another rule cannot be replayed.

Callbacks are trusted compiled code, not sandboxed code. Their own cost and
eligible-handle arrays count towards selected-extension performance; no linear
runtime guarantee is made for arbitrary callbacks. Delimiter and projected-child probes
exercise the architecture without shipping those dialect features. See
[ExtensionContracts.md](ExtensionContracts.md) for the complete contract.

## Source spelling and rendering

`collectSyntaxDetails: true` records exact original byte tokens for emphasis,
code delimiters/content, escapes/entities, hard-break syntax, link components
and markers, raw inline HTML, fence markers/info and extension roles. Disjoint
pieces produce separate tokens; contiguous pieces coalesce. Empty destinations,
titles and fence info retain insertion ranges. CRLF, Unicode and container
prefix tests assert original offsets. Existing transform tokens on text replaced
by inline nodes remain owned by the containing paragraph/heading.

Entity decoding is single pass, with CommonMark decimal/hexadecimal digit
limits and replacement of NUL/surrogates/out-of-range scalars. Code and HTML
bypass escape/entity decoding. NUL replacement also applies before reference
label lookup and URL scanning, with dedicated regression cases. The generated 2,125-name entity table uses pinned BSD swift-cmark data.
Reference keys compare folded UTF-8 bytes, avoiding Swift String's extra
canonical-equivalence matching. NBSP and other Unicode separators are preserved
inside labels; the narrower label-whitespace rule is independent of emphasis
flanking. This corrects the M1 probe that incorrectly rejected a NBSP-only label.
Full non-Turkic case folding uses the official Unicode 17.0.0 C/F mappings
(1,585 entries), including newer scripts missing from the older C reference.
Both inputs have reproducible hashes/generation and licence terms in `NOTICE`.
No external Unicode runtime or locale dependence is introduced.

`HTMLRenderer` escapes source HTML and removes recognized comments by default.
Generated links/images percent-encode unsafe URL bytes and reject decoded,
case-insensitive javascript/vbscript/data/file schemes, including ASCII control
obfuscation. Raw-HTML permission does not disable URL checks. Trusted fixtures
explicitly use `HTMLRenderer.conformance` (raw HTML/comments/unsafe URLs allowed,
no anchors). Caller hooks continue to return trusted HTML. GFM tag filtering
and broader security hardening remain their planned gates.

Strict fixture equality remains the protected comparison. The optional test
normalizer only removes generated br/hr/img closing slashes, preserving text
whitespace, attributes, comments/declarations, code and original raw HTML.
Normalization tests do not hide strict fixture failures.

## Portable diagnostic/fix contract

`DocumentDiagnostic` carries provider/code, category/severity, keyed structured
messages/default text, exact source or physical-line/document locations,
related locations and optional fixes. Findings do not share the parser's
configuration/resource/runtime error channels. An unmatched Markdown delimiter
is a legal literal fallback and does not automatically create a finding.

`DiagnosticReport` validates findings against exact source bytes, carries
provider version/dialect/configuration identity and sorts by source location,
severity, code/message key, then stable provider emission order. The caller
must still attach its full session/text stamp before accepting a result.

`SuggestedEdit` retains expected/replacement bytes, including malformed UTF-8.
`SuggestedFix` orders edits, validates expected byte lengths, rejects overlaps
and insertions touching another edit boundary, and checks all preconditions
before producing a new byte snapshot. It does not apply changes to an editor
or file. Matching only edited substrings does not replace the caller's full
snapshot/configuration check. Tests cover stale fixes, invalid bytes,
zero-length/related ranges and CRLF line boundaries.

Native lint rules, suppressions, UTF-16 conversion, accessible problem navigation
and Setzkit's stale-result/IME/undo-safe transaction adapter remain M3 work.

## Validation

The [evidence directory](Validation/M2/) contains command output and a receipt.
The library has no new runtime dependency or platform-only core import.

- macOS/ARM64, Swift 6.4.2: **96 tests** (89 library, 7 spec/normalizer), all pass.
- macOS/ARM64, Swift 6.2 with its matching Testing runtime and the installed
  macOS 14.4 SDK: **96 tests**, all pass. Deployment target remains macOS 15;
  this does not prove minimum-OS execution.
- Existing Linux/x86-64 host, Swift 6.4.2/glibc: **96 tests**, all pass. Only
  Package.swift, Sources and Tests were transferred to a dedicated task directory
  after explicit owner approval; the task directory was removed after capturing
  the successful output. This is not Linux/Swift 6.2 coverage.
- Exact fixtures: **652/652 CommonMark**, **641/672 GFM**. All original 339 IDs
  in each corpus are preserved; the baseline adds all newly passing IDs, with
  no fixture/digest changes. CommonMark also asserts completeness explicitly.
- Pinned C oracle: **4,786 comparisons** (3,919 prior block/reference/BOM plus
  867 new balanced-inline documents), all pass. Older GFM nested-strong semantics
  are not an oracle for CommonMark 0.31.2: those inputs use the authoritative
  0.31.2 fixtures. GFM differences/extensions remain M4 work.
- Offline Python checks: **17 tests**, including reproducible table generation
  and pinned source-data hashes.

Reproduce library checks with `swift test`, Python checks with
`python3 -I -m unittest discover -s Scripts`, and reference checks with
`swift test --package-path Tools --filter 'ContainerReferenceTests|InlineReferenceTests'`.
For the Swift 6.2 SDK/runtime setup see [Portability.md](Portability.md).
In restricted workspaces use isolated writable compiler/package caches and
scratch directories; release builds use `-debug-info-format none`.

## Performance and acceptance

The fixed additional-total-parse allowance stays **0.5 / 8 / 40 ms**, against
M1's hashed baseline. The block optimisation from merged PR #10 is included;
its gain is reserve, not a larger allowance. Selected block/inline callbacks
count inside the same allowance. `check_m2_budget.py --variant selected-registry`
and `--variant selected-inline` enforce this without falling back to a cheaper
core case when selected cases are absent. Annotation-on costs are measured
separately; the frozen gate explicitly specifies annotations off.

Three owner-authorized full **48-case** runs are retained, including failed
attempts. The initial core medians were **3.330 / 34.996 / 177.603 ms**. Scratch
reuse lowered them to **3.205 / 33.440 / 170.656 ms**, still above the M2
allowance despite passing the general C ratio/absolute limits. Reserving exact
projection capacities, avoiding literal/code-span copies, using byte-set trigger
dispatch and a single-backtick fast path produced **2.777 / 29.557 / 156.500 ms**.
The full capacity run passes both the general gate and all three M2 variants.
Its C controls drift **+0.4% / +5.1% / +2.7%** from the frozen controls, within
10%. No baseline, fixture, allowance or limit was widened.

The last two correctness corrections retain exact empty CRLF insertion ranges
and choose first reference definitions by source offset even when a valid
transform reorders flat node storage. A final **30-case confirmation** covers
both core/GFM controls, selected rules, annotations and reference workloads on
those exact sources. Its filter is checked against the known names; an earlier
empty selection is retained as a failed invocation, not validation. Final
confirmation passes the general gate and all three frozen M2 variants. Its C
controls drift -2.2% / -4.2% / -0.1%, within 10%. Results and gate output are recorded in `Validation/M2/benchmark-final.md`
and the corresponding JSON reports.

| mixed-v1 | Core, ms | C sourcepos, ms | Ratio | Selected inline, ms | Selected block, ms | Syntax on, ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 100 KB | 2.728 | 1.720 | 1.59× | 2.714 | 2.830 | 3.445 |
| 1 MB | 28.230 | 19.104 | 1.48× | 28.951 | 29.508 | 37.388 |
| 5 MB | 146.670 | 95.879 | 1.53× | 149.160 | 152.044 | 188.088 |

All selected-rule cases fit the unchanged M1 total plus M2 allowance. The
smallest remaining allowance is about **0.138 ms** at 100 KB with the selected
block rule; that is reserve, not a promise about arbitrary callbacks. At 1 MB,
core parsing allocates about **110 K / 58 MB** gross, compared with C's
**224 K / 30 MB**. Annotation-on parsing measures **37.388 ms / 186 K / 72 MB**;
its optional cost is real and separately reported. Gross allocation volume is
not peak RSS or retained size. GFM ratios remain informational until M4.

The early short probe is diagnostic only, without allocation interposition,
simultaneous C controls or document deallocation inside its clock. It is not
used as a gate result and must not be mixed with historical C controls.
Source digests, raw exports, Python gate results and the final source receipt
are retained in [Validation/M2](Validation/M2/). Unit/portability checks do not
claim M3 editor/device integration or M6 fuzzing/hostile-input completion.

Merged branches for PRs #7–#10 were verified contained in `origin/main` with
no open dependent PRs. Their four local branches and three clean worktrees
were removed; the unrelated detached scratch worktree was retained. Remote
cleanup completed after explicit owner approval, using SHA-bound leases. No M2 branch push,
PR creation, tag, release or publication is included in this implementation.
