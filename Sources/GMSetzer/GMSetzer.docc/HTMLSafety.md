# HTML policies and trust boundaries

Choose explicit policies when turning untrusted Markdown into HTML.

## Default policy

`HTMLRenderer()` escapes raw HTML, omits recognised HTML comments and
neutralises dangerous decoded URL schemes. HTTP, HTTPS, mailto, relative URLs
and fragment links follow the renderer's URL policy. The GFM tag filter is
part of a selected GFM document's rendering policy.

```swift
let html = try MarkdownHTML.render("<script>alert(1)</script>")
// The script is escaped text, not an executable element.
```

The output is an HTML fragment. The package neither fetches linked resources
nor sanitises a page shell or CSS supplied by the caller.

## Explicit opt-ins

`allowRawHTML`, `preserveHTMLComments`, `allowUnsafeURLs` and
`allowedURLSchemes` are independent renderer choices. Allowing raw HTML does
not sanitise it. `HTMLRenderer.conformance` permits unsafe constructs for
trusted reference fixtures; it is not a production policy for untrusted input.

## Rendering hooks

Both ordinary and contextual hooks supply trusted HTML. Their replacement or
wrapper strings bypass text escaping; use `HTMLRenderer.escape` for text
interpolated into markup. The caller also owns any URL or script policy in
its hooks. The convenience API preserves an explicitly supplied renderer's
policies and composes standard selected-extension recipes on top.

## Limits

The parser limits container and custom-inline recursion depth. These are not
document-size, execution-time or output-memory limits. Bound input and schedule
work at the application boundary. Synchronous parsing has no cancellation
checkpoint; progressive emission exposes checkpoints after parsing completes.
