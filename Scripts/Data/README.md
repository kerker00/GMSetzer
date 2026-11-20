# Inline table inputs

- `cmark-entities.inc`: `src/entities.inc` at swift-cmark revision
  `08ddb528923cc1a6527e02b7a1aee9e516ca749a`; BSD-2/MIT terms are in
  `cmark-COPYING`. The 2,125 semicolon-terminated names are the CommonMark
  subset of the HTML5 list; legacy no-semicolon aliases are not accepted.
- `CaseFolding-17.0.0.txt`: official Unicode 17.0.0 data from
  <https://www.unicode.org/Public/17.0.0/ucd/CaseFolding.txt>.
  Unicode License V3 is in `Unicode-LICENSE.txt` and the root `NOTICE`.
  Generation uses C/F mappings for full, locale-independent non-Turkic folding;
  S/T mappings are intentionally excluded.

`Scripts/generate_inline_tables.py` regenerates the checked-in Swift source
without network access. `Scripts/test_inline_tables.py` protects the exact
input SHA-256 digests and byte-identical generation. Updating these pinned
inputs is a separate, reviewable data change.
