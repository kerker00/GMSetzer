import GMSetzer

precondition(GMSetzerVersion.current == "1.0.0")
precondition(NativeAnalyzer.version == "1.0.0")
let implementations = [FrontMatter.implementation, Footnotes.implementation,
                       Math.implementation, Alert.implementation, Callout.implementation]
let profile = Profile(name: "release-all-m5", extensions: Profile.gfm.extensions
    + implementations.map { ExtensionConfiguration($0.identifier) })
let parser = try MarkdownParser(profile: profile, extensions: implementations,
                                collectSyntaxDetails: true).validated()
let source = """
---
title: Release
---

# Heading Ä😀

[first][later] $x$[^a]

> [!NOTE]
> Alert body

> [!tip]- Folded
> Callout body

- [x] Task

[^a]: note
[later]: https://example.com

"""
let document = parser.parse(source)
precondition(document.source == Array(source.utf8))
precondition(document.tokens?.isEmpty == false)
precondition(SourceIndex(document).utf16Count == source.utf16.count)
precondition(DocumentIndex(document).outline().count == 1)
let report = try NativeAnalyzer.analyze(document, dialect: .gfm,
    configuration: NativeAnalysisConfiguration(rules: Set(NativeRule.allCases)))
precondition(report.providerVersion == "1.0.0")
let math: ContextualHTMLRendererHook = { context in
    Math(context.tree.document, at: context.index).map {
        .replace("<span class=\"math\">\(HTMLRenderer.escape($0.tex))</span>")
    }
}
let base = HTMLRenderer(includeSourceRanges: true, sourceAnchorPrefix: "release-",
    hooks: [FrontMatter.kind: { _, _ in .replace("") }],
    contextualHooks: [Math.inlineKind: math, Math.blockKind: math], hookBehavior: .independent)
let renderer = FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(base))
let expected = renderer.render(document)
let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
precondition(plan.mode == .structural && plan.groups.count > 2)
precondition(plan.groups.last?.kind == .appendix)
var assembled = ""
let count = try plan.forEachGroup { _, html in assembled += html; return true }
precondition(count == plan.groups.count && assembled == expected)
let reversed = try plan.groups.reversed().map { ($0.ordinal, try plan.renderGroup(at: $0.ordinal)) }
precondition(reversed.sorted { $0.0 < $1.0 }.map(\.1).joined() == expected)
let firstOnly = try plan.forEachGroup { _, _ in false }
precondition(firstOnly == 1)
enum ProbeStop: Error { case requested }
do {
    _ = try plan.renderGroup(at: 0, checkpoint: { throw ProbeStop.requested })
    preconditionFailure("Checkpoint did not stop emission")
} catch ProbeStop.requested {}
precondition(expected.contains("https://example.com"))
precondition(expected.contains("class=\"math\">x"))
precondition(expected.contains("Alert body") && expected.contains("Callout body"))
precondition(expected.contains("<details") && expected.contains("footnotes"))
let rawRenderer = FootnotesHTMLRenderer(renderer: .conformance)
let fallback = try rawRenderer.prepare(document)
precondition(fallback.mode == .wholeDocument(.rawHTML) && fallback.groups.count == 1)
let fallbackHTML = try fallback.renderGroup(at: 0)
precondition(fallbackHTML == rawRenderer.render(document))
print("GMSetzer 1.0.0 standalone consumer passed: version/provider, all M5, GFM, tokens/positions, grouped/full/reverse/stop/cancellation/fallback HTML")

let convenience = try MarkdownHTML.render(source, parser: parser, renderer: base)
precondition(convenience == expected)
let safeHTML = try MarkdownHTML.render("<script>alert(1)</script>\n\n[bad](javascript:alert(1))")
precondition(safeHTML.contains("&lt;script&gt;") && !safeHTML.contains("href=\"javascript:"))
let repaired = try MarkdownHTML.render(bytes: [0x23, 0x20, 0xFF, 0x0A])
precondition(repaired == "<h1>�</h1>\n")
let invalid = MarkdownParser(profile: Profile(name: "missing", extensions: [ExtensionConfiguration("missing")]))
do {
    _ = try MarkdownHTML.render("text", parser: invalid)
    preconditionFailure("Invalid configuration was accepted")
} catch is ConfigurationError {}
var pending = [0]
var visited: [Int] = []
while let node = pending.popLast() {
    visited.append(node)
    pending.append(contentsOf: document.children(of: node).reversed())
}
precondition(visited.count == document.nodes.count && Set(visited).count == document.nodes.count)
print("GMSetzer 1.0.0 convenience safety/configuration/bytes and public tree queries passed")
