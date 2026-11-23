# Progressive HTML

Prepare complete-document context, then request structural HTML groups on demand.

```swift
let document = MarkdownParser(profile: .gfm).parse(source)
let plan = try HTMLRenderer().prepare(document, maximumSourceBytesPerGroup: 32_768)
try plan.forEachGroup(checkpoint: { try Task.checkCancellation() }) { group, html in
    // Consume or store this group's HTML in the caller's chosen order.
    return true
}
```

Parsing is complete before preparation. The plan owns its immutable document
and resolves later definitions against complete-document context. Group source
sizes are soft budgets; a giant block remains indivisible. Neither bounded
peak memory nor early input-stream output follows from grouping.

Inspect `HTMLRenderPlan.mode`. Raw HTML that may cross block boundaries and
document-order hooks require a whole-document fallback. Only declare hooks
independent when their markup and side effects satisfy that contract.

For selected footnotes, use `FootnotesHTMLRenderer.prepare` so definitions,
numbering, references and the appendix share the same context. Compose
`AdmonitionHTML.renderer()` before it when alerts/callouts are selected.
The `MarkdownHTML` convenience function returns complete HTML and does not
create a plan.

Ordinals, node indices, ranges and anchors belong to one plan's snapshot.
The caller owns revision checks, scheduling, transfer, layout and scroll state.
Cancellation is checked between renderer events; one literal or caller hook
cannot be interrupted midway.
