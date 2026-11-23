# Getting started

Choose a simple HTML fragment or retain a parsed document for additional services.

## Install

Add the public repository `https://github.com/kerker00/GMSetzer.git` in Xcode
or Swift Package Manager and depend on the `GMSetzer` product. This catalog
describes the 1.0 API. Use a matching released tag; older previews can have
different APIs. A 1.x dependency uses an up-to-next-major requirement:

```swift
.package(url: "https://github.com/kerker00/GMSetzer.git", from: "1.0.0")
```

## Render an HTML fragment

```swift
import GMSetzer

let parser = MarkdownParser(profile: .gfm)
let html = try MarkdownHTML.render("- [x] Done", parser: parser)
```

The convenience function validates configuration, parses once, and composes
the standard HTML recipes for selected footnotes, alerts and callouts. It
returns an HTML fragment; the caller supplies any page shell, stylesheet or
web view. Raw HTML is escaped by default. See <doc:HTMLSafety>.

## Retain the document

```swift
let parser = MarkdownParser(profile: .gfm, collectSyntaxDetails: true)
let document = try parser.validated().parse("# Heading\n\nBody *text*.")
let html = HTMLRenderer().render(document)
let headings = DocumentIndex(document).outline()
let positions = SourceIndex(document)
```

`parse(bytes:)` accepts original UTF-8 bytes. Malformed sequences remain in
`Document.source`; text literals are replacement-decoded. Byte ranges always
refer to that original snapshot. See <doc:EditorIntegration>.

## Select a smaller product

Use `SetzerSyntax` for tree/position/diagnostic values, `SetzerParser` for
CommonMark and custom rules, `SetzerExtensions` for GFM and optional syntax,
`SetzerHTML` for core rendering, and `SetzerAnalysis` for optional native rules.
The `GMSetzer` product re-exports them and supplies HTML composition helpers.
