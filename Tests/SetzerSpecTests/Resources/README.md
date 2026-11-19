# Specification examples

These files are test data, not part of the library, and are **not** covered
by the MIT licence of GMSetzer.

| File | Source | Licence |
| --- | --- | --- |
| `commonmark-0.31.2.json` | [CommonMark Spec 0.31.2](https://spec.commonmark.org/0.31.2/), `spec.json` | [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), © John MacFarlane |
| `gfm-0.29.json` | [GitHub Flavored Markdown Spec 0.29-gfm](https://github.github.com/gfm/), `test/spec.txt` of [cmark-gfm](https://github.com/github/cmark-gfm), converted by `Scripts/convert-gfm-spec.py` | [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), © John MacFarlane, GitHub |

Regenerate with `Scripts/update-specs.sh`. The GFM file adds an `extension`
field taken from the example fence (`table`, `strikethrough`, `autolink`,
`tagfilter`, `disabled`).

`baseline.json` records how many examples pass. The spec tests fail when the
number drops; raise it when more examples pass.
