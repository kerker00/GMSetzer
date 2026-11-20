public import SetzerSyntax

/// Hook output is trusted HTML supplied by the caller, not sanitised document
/// input. A nil result uses normal rendering. Wrapping renders children only,
/// retaining built-in list tightness. The hook owns its opening/closing markup.
public enum HTMLRendering: Sendable {
    case replace(String)
    case wrapChildren(open: String, close: String)
}

public struct HTMLRendererContext: Sendable {
    public let index: Int
    public let sourceAnchorID: String?
    /// Tight-list paragraphs and list items receive the same scheduling context
    /// as the built-in renderer, including when their ancestors are wrapped.
    public let tightItem: Bool
    public let tree: DocumentIndex
    public var node: Node { tree.document.nodes[index] }
    public var parent: Int? { tree.parent(of: index) }
    public var ancestors: [Int] { tree.ancestors(of: index) }
}

public typealias ContextualHTMLRendererHook = @Sendable (HTMLRendererContext) -> HTMLRendering?
public typealias HTMLRendererHook = @Sendable (Node, Document) -> HTMLRendering?

/// Iterative rendering of CommonMark blocks and inlines. Source
/// literals and HTML blocks are escaped by default. Raw HTML and comment
/// preservation require explicit options. Hook output is a caller trust boundary.
public struct HTMLRenderer: Sendable {
    public let includeSourceRanges: Bool
    public let sourceAnchorPrefix: String?
    public let allowRawHTML: Bool
    public let preserveHTMLComments: Bool
    public let allowUnsafeURLs: Bool
    private let contextualHooks: [NodeKind: ContextualHTMLRendererHook]
    private let hooks: [NodeKind: HTMLRendererHook]

    public init(includeSourceRanges: Bool = false, sourceAnchorPrefix: String? = nil, allowRawHTML: Bool = false,
                preserveHTMLComments: Bool = false, allowUnsafeURLs: Bool = false, hooks: [NodeKind: HTMLRendererHook] = [:],
                contextualHooks: [NodeKind: ContextualHTMLRendererHook] = [:]) {
        self.includeSourceRanges = includeSourceRanges
        self.sourceAnchorPrefix = sourceAnchorPrefix
        self.allowRawHTML = allowRawHTML
        self.preserveHTMLComments = preserveHTMLComments
        self.allowUnsafeURLs = allowUnsafeURLs
        self.hooks = hooks
        self.contextualHooks = contextualHooks
    }

    private enum Event { case enter(Int, tightItem: Bool = false), output(String) }

    public func render(_ document: Document) -> String {
        let tree = contextualHooks.isEmpty ? nil : DocumentIndex(document)
        var output = ""
        var pending: [Event] = [.enter(0)]
        while let event = pending.popLast() {
            switch event {
            case .output(let text): output += text
            case .enter(let index, let tightItem):
                let node = document.nodes[index]
                let contextual = tree.flatMap { tree in
                    contextualHooks[node.kind]?(HTMLRendererContext(index: index, sourceAnchorID: sourceAnchorID(forNode: index), tightItem: tightItem, tree: tree))
                }
                if let directive = contextual ?? hooks[node.kind]?(node, document) {
                    switch directive {
                    case .replace(let html): output += html
                    case .wrapChildren(let open, let close):
                        output += open
                        pending.append(.output(close))
                        scheduleChildren(index, document: document, tightItem: tightItem, pending: &pending)
                    }
                    continue
                }
                switch node.data {
                case .document:
                    scheduleChildren(index, document: document, pending: &pending)
                case .paragraph:
                    if !tightItem {
                        output += "<p\(anchors(node, index: index))>"
                        pending.append(.output("</p>\n"))
                    }
                    scheduleChildren(index, document: document, pending: &pending)
                case .blockQuote:
                    output += "<blockquote\(anchors(node, index: index))>\n"
                    pending.append(.output("</blockquote>\n"))
                    scheduleChildren(index, document: document, pending: &pending)
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
                    scheduleChildren(index, document: document, pending: &pending)
                case .listItem:
                    let children = document.children(of: index).filter { document.nodes[$0].kind != .referenceDefinition }
                    output += "<li\(anchors(node, index: index))>"
                    if let first = children.first, !tightItem || document.nodes[first].kind != .paragraph { output += "\n" }
                    pending.append(.output("</li>\n"))
                    scheduleItemChildren(children, document: document, tightItem: tightItem, pending: &pending)
                case .heading(let level):
                    output += "<h\(level)\(anchors(node, index: index))>"
                    pending.append(.output("</h\(level)>\n"))
                    scheduleChildren(index, document: document, pending: &pending)
                case .text(let text): output += Self.escape(text)
                case .softBreak: output += "\n"
                case .hardBreak: output += "<br />\n"
                case .code(let literal): output += "<code>\(Self.escape(literal))</code>"
                case .emphasis, .strong:
                    let tag = node.kind == .strong ? "strong" : "em"
                    output += "<\(tag)>"
                    pending.append(.output("</\(tag)>"))
                    scheduleChildren(index, document: document, pending: &pending)
                case .link(let destination, let title):
                    output += "<a href=\"\(url(destination))\""
                    if let title, !title.isEmpty { output += " title=\"\(Self.escape(title))\"" }
                    output += ">"
                    pending.append(.output("</a>"))
                    scheduleChildren(index, document: document, pending: &pending)
                case .image(let destination, let title):
                    output += "<img src=\"\(url(destination))\" alt=\"\(Self.escape(imageText(index, document: document)))\""
                    if let title, !title.isEmpty { output += " title=\"\(Self.escape(title))\"" }
                    output += " />"
                case .htmlInline(let literal):
                    let html = preserveHTMLComments ? literal : Self.removingHTMLComments(literal)
                    output += allowRawHTML ? html : Self.escape(html)
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
                    output += allowRawHTML ? html : Self.escape(html)
                case .custom:
                    if node.firstChild != nil {
                        scheduleChildren(index, document: document, pending: &pending)
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
        return output
    }

    private func scheduleChildren(_ index: Int, document: Document, tightItem: Bool = false, pending: inout [Event]) {
        switch document.nodes[index].data {
        case .list(let attributes):
            for child in document.children(of: index).reversed() {
                pending.append(.enter(child, tightItem: attributes.isTight))
            }
        case .listItem:
            let children = document.children(of: index).filter { document.nodes[$0].kind != .referenceDefinition }
            scheduleItemChildren(children, document: document, tightItem: tightItem, pending: &pending)
        default:
            for child in document.children(of: index).reversed() { pending.append(.enter(child)) }
        }
    }

    private func scheduleItemChildren(_ children: [Int], document: Document, tightItem: Bool, pending: inout [Event]) {
        for (position, child) in children.enumerated().reversed() {
            let unwrapped = tightItem && document.nodes[child].kind == .paragraph
            if unwrapped && position + 1 < children.count { pending.append(.output("\n")) }
            pending.append(.enter(child, tightItem: unwrapped))
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
                if !["http", "https", "mailto"].contains(String(decoding: scheme, as: UTF8.self)) { return "" }
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

    /// IDs identify nodes in this render only, not across edits. The caller
    /// namespaces separate previews by choosing a prefix.
    public func sourceAnchorID(forNode index: Int) -> String? {
        sourceAnchorPrefix.map { $0 + String(index) }
    }

    private func anchors(_ node: Node, index: Int) -> String {
        let id = sourceAnchorID(forNode: index).map { " id=\"\(Self.escape($0))\"" } ?? ""
        return id + (includeSourceRanges ? " data-source-start=\"\(node.range.lowerBound)\" data-source-end=\"\(node.range.upperBound)\"" : "")
    }

    public static func escape(_ text: String) -> String {
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
