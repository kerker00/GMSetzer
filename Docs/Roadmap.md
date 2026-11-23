# GMSetzer roadmap

23 November 2026. This roadmap describes GMSetzer's own development priorities.
The 1.0 Markdown syntax scope is implemented; API/documentation acceptance
and release verification are still in progress. Later stages are proposed
work packages, not published capabilities or delivery dates. Minor-version
labels express sequence and can be split when acceptance requires it.

## Principles

- Finish a reliable 1.0 before adding more Markdown dialect syntax.
- Preserve CommonMark/GFM behaviour and source compatibility in 1.x.
- Make new syntax opt-in, with independent selection, exact original-byte
  ranges, optional source-spelled tokens and defined HTML behaviour.
- Keep the six products consumer-neutral, pure Swift and free of runtime
  dependencies. Rendering engines, CSS, resource loading and editor UI stay
  with the caller.
- Set acceptance criteria before implementation. Retain exact source and
  measurement identities; functional tests do not establish performance.

## 1.0 — stable package and public documentation

**Goal:** publish the existing parser/editor-service scope with a reviewed
source API, usable documentation and reproducible release checks.

CommonMark, GFM, raw YAML/TOML front matter, named footnotes, opaque TeX,
alerts/callouts, original-byte syntax/positions, native findings and full/
progressive HTML are already implemented. The new validated HTML facade and
six DocC catalogs are in the M8 candidate.

| Work | Done when |
| --- | --- |
| Documentation build reliability | A clean checkout builds all six library DocC archives on the minimum Swift toolchain; test-runner module generation cannot break library documentation |
| Final API review | Product boundaries, defaults, errors, preconditions, identifiers, ownership, configuration and concurrency contracts are reviewed and recorded; decide whether the current public tree-query surface is sufficient |
| Documentation review | Public types and consequential members explain their contracts; examples, trust boundaries, coordinate units and progressive fallbacks are checked; missing-comment inventory is reviewed |
| Compatibility gate | The candidate API inventory passes independently on macOS/Linux and the minimum compiler, with meaningful regression checks for breaking changes |
| Correctness and portability | Protected CommonMark/GFM corpora, extension combinations, normal Debug/Release suites, optimized builds and script checks pass on the declared matrix |
| M7/M8 acceptance | Performance/robustness evidence and its limits, API/docs review and remaining platform coverage receive explicit acceptance |
| Release preparation | Exact merged commit, final version identity, final notes and successful CI agree; independent consumer and source archive checks pass |
| Publication | Owner-confirmed tag/release and Swift Package Index submission; verify real package/documentation results before advertising them |

[M8 readiness](M8Readiness.md), [proposed API policy](APIStability.md) and
[release procedure](Releasing.md) track execution. No intermediate preview tag
is technically required. New dialect syntax is outside this release stage.

## 1.1 — document links and attributes

**Goal:** support predictable navigation and semantic markup in Markdown
documents, without embedding application-specific file resolution.

- Opt-in `[[target]]` and `[[target|label]]` wikilinks, with a precise escaping,
  nesting, unresolved-target and source-token contract.
- Explicit heading IDs and classes, such as `# Heading {#overview .wide}`.
  Define duplicate IDs, malformed attributes and safe HTML attribute handling.
- Define a caller-controlled link-resolution/rendering boundary. Recognising
  a target does not open files, fetch URLs or assign project identity.
- Consider generated heading slugs separately from existing source anchors:
  content-derived link IDs and snapshot-local editor anchors serve different purposes.

**Done when:** selections remain independent; off-mode outputs stay unchanged;
Unicode/escaping, nested containers, source projections and HTML trust boundaries
have regression coverage. Full and grouped HTML agree, with exact ranges/tokens
and measured selected-feature costs before speed claims.

## 1.2 — additional writing syntax

**Goal:** add a focused set of opt-in authoring constructs.

Candidate order: definition lists; highlighted text (`==text==`);
superscript/subscript; spoiler or inserted-text spans. Emoji shortcodes and
smart punctuation are separate options, since they transform literal text
rather than merely introducing containers.

**Done when:** each syntax has a written delimiter/precedence/escaping contract,
independent switches, original-byte provenance and a safe HTML recipe. Syntax
inside code, links, math and custom rules remains protected. Typography defines
language policy and does not silently alter strict CommonMark/GFM literals.
Select a bounded subset for each actual release rather than coupling all candidates.

## 1.3 — tree processing and Markdown output

**Goal:** make structured document inspection and transformation convenient,
and allow callers to generate normalised Markdown from a validated tree.

- Public traversal/visitor conveniences with clear subtree skipping and
  source-order semantics, where the 1.0 API review identifies a need.
- Explicit transformation helpers that preserve tree validity and make source/
  token ownership after edits unambiguous.
- A Markdown writer with configurable markers, fences and wrapping, plus an
  explicit policy for custom nodes and selected extensions.

**Done when:** parse/write/parse tests preserve the declared semantic subset;
unsupported custom content has a defined fallback; edits cannot silently reuse
stale positions. A normalising writer is not advertised as lossless preservation
of original spelling, whitespace or comments.

## 1.4 and later — reusable document extensions

**Goal:** add further document structures only for demonstrated use cases.

Candidates include attributed/fenced containers, block directives with named
arguments, additional annotation/query conveniences and coherent optional
profiles assembled from individually tested extensions. Wikilink embeds need
a separate syntax/content-resolution design; they do not follow automatically
from link support.

**Done when:** nested/projected source ownership, interaction with existing
extensions, caller-controlled resource handling and rendering fallbacks are
specified and tested. Profile names do not imply compatibility with every
external dialect feature.

## Separate architectural investigations

| Investigation | Required decision before implementation |
| --- | --- |
| Event-oriented parsing/output without a retained full AST | Define which source, validation, editor and reference services remain available; measure whether the alternative reduces actual workload cost |
| Incremental reparsing after edits | Define revision ownership, invalidation of references/list context/footnotes and exact result equivalence against a full parse |
| Input streaming | Specify late definitions, ownership, finalisation and explicit restrictions/fallbacks; progressive HTML alone does not provide this |
| Additional renderers | Choose a concrete need for structured tree export, LaTeX or another format and a policy for every extension/custom node |
| Further throughput, memory and fuzzing work | Use current profiles and representative workloads to choose the next change; preserve controls and separate gross allocation traffic from retained/peak memory |

No architecture rewrite or new major version is scheduled by this table.
Additive APIs can fit 1.x; a change that breaks the accepted contract requires
a separate major-version proposal. Built-in TeX/code-highlighting engines,
diagram execution, document styling and application-level linking are outside
the current runtime dependency boundary.
