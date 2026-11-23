public import SetzerSyntax

/// Hook output is trusted HTML supplied by the caller, not sanitised document
/// input. A nil result uses normal rendering. Wrapping renders children only,
/// retaining built-in list tightness. The hook owns its opening/closing markup.
public enum HTMLRendering: Sendable {
    case replace(String)
    case wrapChildren(open: String, close: String)
}

/// Snapshot-local node, ancestry and list context for a trusted renderer hook.
public struct HTMLRendererContext: Sendable {
    public let index: Int
    fileprivate let anchorPrefix: String?
    /// Constructed only when a hook requests the identifier.
    public var sourceAnchorID: String? { anchorPrefix.map { $0 + String(index) } }
    /// Tight-list paragraphs and list items receive the same scheduling context
    /// as the built-in renderer, including when their ancestors are wrapped.
    public let tightItem: Bool
    public let tree: DocumentIndex
    fileprivate let renderer: HTMLRenderer
    /// Package composition renders title inlines with all currently active
    /// hooks (including footnote calls), sharing this snapshot's tree index.
    package func renderChildren(of index: Int) -> String {
        renderer.renderChildren(tree.document, of: index, tree: tree)
    }
    public var node: Node { tree.document.nodes[index] }
    public var parent: Int? { tree.parent(of: index) }
    public var ancestors: [Int] { Array(tree.ancestors(of: index)) }
}

/// Supplies trusted markup with ancestry/context, or nil for default rendering.
public typealias ContextualHTMLRendererHook = @Sendable (HTMLRendererContext) -> HTMLRendering?
/// Supplies trusted markup for a node/snapshot, or nil for default rendering.
public typealias HTMLRendererHook = @Sendable (Node, Document) -> HTMLRendering?

/// Iterative rendering of CommonMark blocks and inlines. Source
/// literals and HTML blocks are escaped by default. Raw HTML and comment
/// preservation require explicit options. Hook output is a caller trust boundary.
public struct HTMLRenderer: Sendable {
    /// Include original-byte source attributes on rendered block elements.
    public let includeSourceRanges: Bool
    /// Optional namespace for snapshot-local block anchor IDs.
    public let sourceAnchorPrefix: String?
    /// Emit source HTML rather than escaped text; this is not sanitisation.
    public let allowRawHTML: Bool
    /// Preserve recognised HTML comments instead of omitting them.
    public let preserveHTMLComments: Bool
    /// Bypass decoded URL scheme checks; intended only for trusted content.
    public let allowUnsafeURLs: Bool
    /// Explicit permitted schemes when URL checks are active; relative URLs
    /// and fragments are handled separately.
    public let allowedURLSchemes: Set<HTMLURLScheme>
    private let escapedAnchorPrefix: String?
    private let contextualHooks: [NodeKind: ContextualHTMLRendererHook]
    private let hooks: [NodeKind: HTMLRendererHook]
    private let independentlyRenderableHooks: Bool

    /// Chooses HTML policies without rendering a document. Hook output is
    /// trusted caller markup. Default hook behaviour requires document order;
    /// opt into independence only when every hook meets that contract.
    public init(includeSourceRanges: Bool = false, sourceAnchorPrefix: String? = nil, allowRawHTML: Bool = false,
                preserveHTMLComments: Bool = false, allowUnsafeURLs: Bool = false, allowedURLSchemes: Set<HTMLURLScheme> = [.http, .https, .mailto], hooks: [NodeKind: HTMLRendererHook] = [:],
                contextualHooks: [NodeKind: ContextualHTMLRendererHook] = [:],
                hookBehavior: HTMLHookBehavior = .documentOrder) {
        self.includeSourceRanges = includeSourceRanges
        self.sourceAnchorPrefix = sourceAnchorPrefix
        self.escapedAnchorPrefix = sourceAnchorPrefix.map(Self.escape)
        self.allowRawHTML = allowRawHTML
        self.preserveHTMLComments = preserveHTMLComments
        self.allowUnsafeURLs = allowUnsafeURLs
        self.allowedURLSchemes = allowedURLSchemes
        self.hooks = hooks
        self.contextualHooks = contextualHooks
        self.independentlyRenderableHooks = (hooks.isEmpty && contextualHooks.isEmpty) || hookBehavior == .independent
    }

    /// `flag` carries the one bit of context a node needs from its parent:
    /// tight-list state for paragraphs and items, header state for table
    /// cells, and a strong parent for strong nodes.
    private enum Event { case enter(Int, flag: Bool = false), output(String) }

    /// Renders a complete validated snapshot as an HTML fragment. The document's
    /// profile-selected HTML policies are applied alongside this renderer's options.
    public func render(_ document: Document) -> String {
        let tree = contextualHooks.isEmpty ? nil : DocumentIndex(document)
        return render(document, events: [.enter(0)], tree: tree, checkpoint: {})
    }

    /// Prepares opt-in, pull-based structural HTML. The complete document is
    /// retained, not reparsed or rendered eagerly. Source-byte size is a soft
    /// grouping budget; a larger block stays intact.
    public func prepare(_ document: Document, maximumSourceBytesPerGroup: Int = 32_768) throws -> HTMLRenderPlan {
        try HTMLRenderPlan(document: document, renderer: self, maximumSourceBytesPerGroup: maximumSourceBytesPerGroup)
    }

    package var needsContextIndex: Bool { !contextualHooks.isEmpty }
    package var omitsReferenceDefinitions: Bool {
        hooks[.referenceDefinition] == nil && contextualHooks[.referenceDefinition] == nil
    }
    package var groupFallback: HTMLRenderPlan.Fallback? {
        if allowRawHTML { return .rawHTML }
        if hooks[.document] != nil || contextualHooks[.document] != nil { return .documentHook }
        if !independentlyRenderableHooks { return .documentOrderHooks }
        return nil
    }

    /// Package-level composition keeps extension HTML in the convenience
    /// module without making the syntax renderer depend on parser extensions.
    package func addingHooks(_ additional: [NodeKind: HTMLRendererHook], independent: Bool = false) -> HTMLRenderer {
        HTMLRenderer(includeSourceRanges: includeSourceRanges, sourceAnchorPrefix: sourceAnchorPrefix,
            allowRawHTML: allowRawHTML, preserveHTMLComments: preserveHTMLComments,
            allowUnsafeURLs: allowUnsafeURLs, allowedURLSchemes: allowedURLSchemes,
            hooks: hooks.merging(additional) { _, replacement in replacement },
            contextualHooks: contextualHooks.filter { additional[$0.key] == nil },
            hookBehavior: independentlyRenderableHooks && (additional.isEmpty || independent) ? .independent : .documentOrder)
    }

    package func addingContextualHooks(_ additional: [NodeKind: ContextualHTMLRendererHook], independent: Bool = false) -> HTMLRenderer {
        HTMLRenderer(includeSourceRanges: includeSourceRanges, sourceAnchorPrefix: sourceAnchorPrefix,
            allowRawHTML: allowRawHTML, preserveHTMLComments: preserveHTMLComments,
            allowUnsafeURLs: allowUnsafeURLs, allowedURLSchemes: allowedURLSchemes,
            hooks: hooks, contextualHooks: contextualHooks.merging(additional) { _, replacement in replacement },
            hookBehavior: independentlyRenderableHooks && (additional.isEmpty || independent) ? .independent : .documentOrder)
    }

    package func render(_ document: Document, tree: DocumentIndex) -> String {
        render(document, events: [.enter(0)], tree: tree, checkpoint: {})
    }

    package func renderChildren(_ document: Document, of index: Int, tree: DocumentIndex) -> String {
        var pending: [Event] = []
        var children: [Int] = []
        scheduleChildren(index, document: document, pending: &pending, children: &children)
        return render(document, events: pending, tree: tree, checkpoint: {})
    }

    package func renderNodes(_ document: Document, nodes: [Int], tree: DocumentIndex?,
                             checkpoint: () throws -> Void) rethrows -> String {
        try render(document, events: nodes.reversed().map { .enter($0) }, tree: tree, checkpoint: checkpoint)
    }

    package func renderChildren(_ document: Document, of index: Int, tree: DocumentIndex,
                                checkpoint: () throws -> Void) rethrows -> String {
        var pending: [Event] = []
        var children: [Int] = []
        scheduleChildren(index, document: document, pending: &pending, children: &children)
        return try render(document, events: pending, tree: tree, checkpoint: checkpoint)
    }

    private func render(_ document: Document, events: [Event], tree: DocumentIndex?,
                        checkpoint: () throws -> Void) rethrows -> String {
        var output = ""
        var pending = events
        // Child indices are copied into events; no event or hook retains this
        // caller-owned scratch array between nodes or separate render calls.
        var children: [Int] = []
        while let event = pending.popLast() {
            try checkpoint()
            switch event {
            case .output(let text): output += text
            case .enter(let index, let tightItem):
                let node = document.nodes[index]
                let contextual = tree.flatMap { tree in
                    contextualHooks[node.kind]?(HTMLRendererContext(index: index, anchorPrefix: sourceAnchorPrefix,
                        tightItem: tightItem, tree: tree, renderer: self))
                }
                if let directive = contextual ?? hooks[node.kind]?(node, document) {
                    switch directive {
                    case .replace(let html): output += html
                    case .wrapChildren(let open, let close):
                        output += open
                        pending.append(.output(close))
                        scheduleChildren(index, document: document, tightItem: tightItem, pending: &pending, children: &children)
                    }
                    continue
                }
                switch node.data {
                case .document:
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .paragraph:
                    if !tightItem {
                        output += "<p\(anchors(node, index: index))>"
                        pending.append(.output("</p>\n"))
                    }
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .blockQuote:
                    output += "<blockquote\(anchors(node, index: index))>\n"
                    pending.append(.output("</blockquote>\n"))
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .list(let attributes):
                    let tag: String
                    switch attributes.style {
                    case .bullet: tag = "ul"; output += "<ul\(anchors(node, index: index))>\n"
                    case .ordered(let start, _):
                        tag = "ol"
                        let startAttribute = start == 1 ? "" : " start=\"\(start)\""
                        output += "<ol\(startAttribute)\(anchors(node, index: index))>\n"
                    }
                    pending.append(.output("</\(tag)>\n"))
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .listItem, .taskListItem:
                    document.children(of: index, into: &children)
                    children.removeAll { document.nodes[$0].kind == .referenceDefinition }
                    output += "<li\(anchors(node, index: index))>"
                    if case .taskListItem(let checked) = node.data {
                        output += checked ? "<input checked=\"\" disabled=\"\" type=\"checkbox\"> "
                                          : "<input disabled=\"\" type=\"checkbox\"> "
                    }
                    if let first = children.first, !tightItem || document.nodes[first].kind != .paragraph { output += "\n" }
                    pending.append(.output("</li>\n"))
                    scheduleItemChildren(children, document: document, tightItem: tightItem, pending: &pending)
                case .heading(let level):
                    output += "<h\(level)\(anchors(node, index: index))>"
                    pending.append(.output("</h\(level)>\n"))
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .text(let text): output += Self.escape(text)
                case .softBreak: output += "\n"
                case .hardBreak: output += "<br />\n"
                case .code(let literal): output += "<code>\(Self.escape(literal))</code>"
                case .emphasis:
                    output += "<em>"
                    pending.append(.output("</em>"))
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .strong:
                    let collapses = document.renderingPolicy.contains(.collapsesNestedStrong)
                    // GitHub's renderer omits the tags of a strong whose parent is strong.
                    if !(collapses && tightItem) {
                        output += "<strong>"
                        pending.append(.output("</strong>"))
                    }
                    if collapses {
                        document.children(of: index, into: &children)
                        for child in children.reversed() {
                            pending.append(.enter(child, flag: document.nodes[child].kind == .strong))
                        }
                    } else { scheduleChildren(index, document: document, pending: &pending, children: &children) }
                case .strikethrough:
                    output += "<del>"
                    pending.append(.output("</del>"))
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .table:
                    output += "<table\(anchors(node, index: index))>\n"
                    document.children(of: index, into: &children)
                    pending.append(.output(children.count > 1 ? "</tbody>\n</table>\n" : "</table>\n"))
                    for position in children.indices.reversed() {
                        let row = children[position]
                        pending.append(.enter(row))
                        if position == 1 { pending.append(.output("<tbody>\n")) }
                    }
                case .tableRow(let isHeader):
                    output += isHeader ? "<thead>\n<tr\(anchors(node, index: index))>\n" : "<tr\(anchors(node, index: index))>\n"
                    pending.append(.output(isHeader ? "</tr>\n</thead>\n" : "</tr>\n"))
                    document.children(of: index, into: &children)
                    for cell in children.reversed() { pending.append(.enter(cell, flag: isHeader)) }
                case .tableCell(let alignment):
                    let tag = tightItem ? "th" : "td"
                    let align: String
                    switch alignment {
                    case .none: align = ""
                    case .left: align = " align=\"left\""
                    case .center: align = " align=\"center\""
                    case .right: align = " align=\"right\""
                    }
                    output += "<\(tag)\(align)\(anchors(node, index: index))>"
                    pending.append(.output("</\(tag)>\n"))
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .link(let destination, let title):
                    output += "<a href=\"\(url(destination))\""
                    if let title, !title.isEmpty { output += " title=\"\(Self.escape(title))\"" }
                    output += ">"
                    pending.append(.output("</a>"))
                    scheduleChildren(index, document: document, pending: &pending, children: &children)
                case .image(let destination, let title):
                    output += "<img src=\"\(url(destination))\" alt=\"\(Self.escape(imageText(index, document: document)))\""
                    if let title, !title.isEmpty { output += " title=\"\(Self.escape(title))\"" }
                    output += " />"
                case .htmlInline(let literal):
                    let html = preserveHTMLComments ? literal : Self.removingHTMLComments(literal)
                    output += allowRawHTML ? rawHTML(html, document: document) : Self.escape(html)
                case .thematicBreak: output += "<hr\(anchors(node, index: index)) />\n"
                case .codeBlock(let info, let literal):
                    output += "<pre\(anchors(node, index: index))><code"
                    if let language = info?.split(whereSeparator: { $0 == " " || $0 == "\t" }).first {
                        output += " class=\"language-\(Self.escape(String(language)))\""
                    }
                    output += ">\(Self.escape(literal))</code></pre>\n"
                case .referenceDefinition: break
                case .htmlBlock(let block):
                    let html = preserveHTMLComments ? block.literal : Self.removingHTMLComments(block.literal)
                    output += allowRawHTML ? rawHTML(html, document: document) : Self.escape(html)
                case .custom:
                    if node.firstChild != nil {
                        scheduleChildren(index, document: document, pending: &pending, children: &children)
                    } else {
                        if let literal = document.customLeafFallbacks[index] {
                            output += Self.escape(literal)
                        } else {
                            // Hand-built trees may omit a projected fallback.
                            let bytes = document.source[node.range.lowerBound..<node.range.upperBound]
                            output += Self.escape(String(decoding: bytes, as: UTF8.self))
                        }
                    }
                }
            }
        }
        try checkpoint()
        return output
    }

    private func scheduleChildren(_ index: Int, document: Document, tightItem: Bool = false,
                                  pending: inout [Event], children: inout [Int]) {
        document.children(of: index, into: &children)
        switch document.nodes[index].data {
        case .list(let attributes):
            for child in children.reversed() {
                pending.append(.enter(child, flag: attributes.isTight))
            }
        case .listItem, .taskListItem:
            children.removeAll { document.nodes[$0].kind == .referenceDefinition }
            scheduleItemChildren(children, document: document, tightItem: tightItem, pending: &pending)
        default:
            for child in children.reversed() { pending.append(.enter(child)) }
        }
    }

    private func scheduleItemChildren(_ children: [Int], document: Document, tightItem: Bool, pending: inout [Event]) {
        for position in children.indices.reversed() {
            let child = children[position]
            let unwrapped = tightItem && document.nodes[child].kind == .paragraph
            if unwrapped && position + 1 < children.count { pending.append(.output("\n")) }
            pending.append(.enter(child, flag: unwrapped))
        }
    }

    /// Dedicated trusted-fixture settings; allowing HTML alone never enables unsafe URLs.
    public static let conformance = HTMLRenderer(allowRawHTML: true, preserveHTMLComments: true, allowUnsafeURLs: true)

    private func url(_ value: String) -> String {
        if !allowUnsafeURLs {
            // A scheme ends before any path/query/fragment separator. Only
            // these browser-safe schemes are allowed; relative URLs remain.
            let prefix = value.utf8.prefix { $0 != 47 && $0 != 63 && $0 != 35 }
            if let colon = prefix.firstIndex(of: 58) {
                let scheme = prefix[..<colon].filter { $0 > 32 && $0 != 127 }
                    .map { (65...90).contains($0) ? $0 + 32 : $0 }
                guard let name = HTMLURLScheme(rawValue: String(decoding: scheme, as: UTF8.self)),
                      allowedURLSchemes.contains(name) else { return "" }
            }
        }
        let safe = "-_.+!*(),%#@?=;:/&$~".utf8
        let hex = Array("0123456789ABCDEF".utf8)
        var bytes: [UInt8] = []
        for byte in value.utf8 {
            if byte == 38 { bytes.append(contentsOf: "&amp;".utf8) }
            else if (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || safe.contains(byte) { bytes.append(byte) }
            else if byte == 39 { bytes.append(contentsOf: "&#x27;".utf8) }
            else { bytes.append(37); bytes.append(hex[Int(byte >> 4)]); bytes.append(hex[Int(byte & 15)]) }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func imageText(_ index: Int, document: Document) -> String {
        var output = ""
        var pending = document.children(of: index).reversed().map { $0 }
        while let current = pending.popLast() {
            let node = document.nodes[current]
            switch node.data {
            case .text(let text), .code(let text): output += text
            case .softBreak, .hardBreak: output += "\n"
            case .htmlInline(let html): output += html
            default: pending.append(contentsOf: document.children(of: current).reversed())
            }
        }
        return output
    }

    /// Raw HTML passes through unless the document's profile selects the GFM
    /// tag filter, which escapes the `<` of a disallowed tag.
    private func rawHTML(_ html: String, document: Document) -> String {
        guard document.renderingPolicy.contains(.filtersDisallowedRawHTML) else { return html }
        return Self.filteringDisallowedTags(html)
    }

    private static let disallowedTags: [[UInt8]] = ["title", "textarea", "style", "xmp", "iframe",
                                                    "noembed", "noframes", "script", "plaintext"].map { Array($0.utf8) }

    /// GFM tag filter (ported from cmark-gfm `tagfilter.c`, BSD-2; see NOTICE): a tag
    /// name must be followed by whitespace, `>` or `/>`; matching ignores case.
    public static func filteringDisallowedTags(_ html: String) -> String {
        let bytes = Array(html.utf8)
        guard bytes.contains(60) else { return html }
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count + 8)
        for index in bytes.indices {
            if bytes[index] == 60 && isDisallowedTag(bytes, at: index) { output.append(contentsOf: "&lt;".utf8) }
            else { output.append(bytes[index]) }
        }
        return String(decoding: output, as: UTF8.self)
    }

    private static func isDisallowedTag(_ bytes: [UInt8], at start: Int) -> Bool {
        let size = bytes.count - start
        guard size >= 3 else { return false }
        var name = start + 1
        if bytes[name] == 47 { name += 1 }
        for tag in disallowedTags {
            var position = name, matched = true
            for expected in tag {
                guard position < bytes.count else { matched = false; break }
                let byte = bytes[position]
                guard (65...90).contains(byte) ? byte + 32 == expected : byte == expected else { matched = false; break }
                position += 1
            }
            guard matched, position < bytes.count else { continue }
            switch bytes[position] {
            // cmark_isspace: tab, LF, CR and space only.
            case 9, 10, 13, 32, 62: return true
            case 47 where position + 1 < bytes.count && bytes[position + 1] == 62: return true
            default: continue
            }
        }
        return false
    }

    /// IDs identify nodes in this render only, not across edits. The caller
    /// namespaces separate previews by choosing a prefix.
    public func sourceAnchorID(forNode index: Int) -> String? {
        sourceAnchorPrefix.map { $0 + String(index) }
    }

    private func anchors(_ node: Node, index: Int) -> String {
        let id = escapedAnchorPrefix.map { " id=\"\($0)\(index)\"" } ?? ""
        return id + (includeSourceRanges ? " data-source-start=\"\(node.range.lowerBound)\" data-source-end=\"\(node.range.upperBound)\"" : "")
    }

    /// Escapes ampersand, angle brackets and double quotes for generated HTML.
    /// This does not validate URLs, sanitise markup or encode single-quoted attributes.
    public static func escape(_ text: String) -> String {
        // Most text needs no escaping. Preserve its existing storage instead
        // of building a byte array and decoding an identical second string.
        guard text.utf8.contains(where: { $0 == 38 || $0 == 60 || $0 == 62 || $0 == 34 }) else { return text }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.utf8.count)
        for byte in text.utf8 {
            switch byte {
            case 38: bytes.append(contentsOf: "&amp;".utf8)
            case 60: bytes.append(contentsOf: "&lt;".utf8)
            case 62: bytes.append(contentsOf: "&gt;".utf8)
            case 34: bytes.append(contentsOf: "&quot;".utf8)
            default: bytes.append(byte)
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
