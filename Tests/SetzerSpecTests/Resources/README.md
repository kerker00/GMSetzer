# Specification examples

These files are test data, not part of the library, and are **not** covered
by the MIT licence of GMSetzer.

| File | Source | Licence |
| --- | --- | --- |
| `commonmark-0.31.2.json` | [CommonMark Spec 0.31.2](https://spec.commonmark.org/0.31.2/), `spec.json` | [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), © John MacFarlane |
| `gfm-0.29.json` | GFM 0.29-derived `test/spec.txt`, pinned to [swift-cmark revision 08ddb528](https://github.com/swiftlang/swift-cmark/blob/08ddb528923cc1a6527e02b7a1aee9e516ca749a/test/spec.txt), a fork of [cmark-gfm](https://github.com/github/cmark-gfm); converted by `Scripts/convert-gfm-spec.py` | [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), © John MacFarlane, GitHub |

Regenerate with `Scripts/update-specs.sh`. URLs/revisions and SHA-256 digests
are fixed in that script; a changed download leaves both fixtures untouched.
Updating versions or source digests is a separate reviewed corpus change.
The pinned Swift fork reproduces the existing fixture without changes.

The GFM file adds an `extension`
field taken from the example fence (`table`, `strikethrough`, `autolink`,
`tagfilter`, `disabled`).

The corpus has 672 examples. Both task list examples (279 and 280) are marked
`disabled` in the upstream source but are required here and run with all other
examples. The 670-example count excluded them and was incomplete for GMSetzer.

`baseline.json` records passing example IDs per profile. The spec tests fail
if any protected example regresses, even if another starts passing. Add new
passing IDs in the same commit. M1 through HTML/references protects 339 CommonMark
and 339 GFM examples. The harness explicitly permits raw HTML and comments for
trusted conformance fixtures; safe-default rendering is tested separately.
At M0 only CommonMark 207 and GFM 176/188 passed; those
rendered empty output and did not demonstrate parser implementation.
