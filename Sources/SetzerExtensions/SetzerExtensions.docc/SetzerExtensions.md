# ``SetzerExtensions``

Select GFM and optional front matter, footnotes, math, alerts and callouts.

## Overview

The GFM profile selects tables, task lists, strikethrough, extended autolinks,
tag filtering and GitHub's nested-strong rendering. Each feature can also be
selected on its own through a profile extension configuration.

For additional syntax, select the public identifier in a profile and pass
its `implementation` to `MarkdownParser`. `FrontMatter` preserves raw bytes;
it does not deserialize YAML/TOML. `Footnotes.Index` numbers reachable cited
notes without expanding cycles. `Math` is opaque TeX, with caller-owned output.
`Alert` and `Callout` preserve parsed Markdown bodies and original positions.

These types describe syntax. HTML composition helpers for footnotes and
admonitions live in the `GMSetzer` convenience product.

## Topics

### Optional syntax
- ``FrontMatter``
- ``Footnotes``
- ``Math``
- ``Alert``
- ``Callout``
