# ``GMSetzer``

Parse Markdown into a source-positioned Swift tree and render HTML with safe defaults.

## Overview

GMSetzer implements CommonMark and GitHub Flavored Markdown, with independently
selected front matter, footnotes, math, alerts and callouts. All six library
products use Swift's standard library and have no external runtime dependencies.
Use Swift 6.2 or later, on macOS 15+, iOS 18+, visionOS 2+, or Linux.

For an HTML fragment:

```swift
import GMSetzer

let html = try MarkdownHTML.render("# Hello\n\n**Swift** Markdown.")
```

For a retained tree, optional tokens, positions, analysis or progressive output,
use `MarkdownParser` and the services re-exported by this module. No parsing,
linting, networking, file access or UI work runs implicitly in the background.

## Topics

### Start here
- <doc:GettingStarted>
- <doc:ExtensionSelection>
- <doc:HTMLSafety>
- <doc:ProgressiveOutput>
- <doc:EditorIntegration>
- <doc:TreeQueries>
- <doc:Compatibility>

### HTML convenience and composition
- ``MarkdownHTML``
- ``FootnotesHTMLRenderer``
- ``AdmonitionHTML``
