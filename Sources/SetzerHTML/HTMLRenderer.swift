public import SetzerSyntax

/// Hook output is trusted HTML supplied by the caller, not sanitised document
/// input. A nil result uses normal rendering. Wrapping renders children only.
public enum HTMLRendering: Sendable {
    case replace(String)
    case wrapChildren(open: String, close: String)
}

public typealias HTMLRendererHook = @Sendable (Node, Document) -> HTMLRendering?

/// Iterative rendering of the currently implemented block tree. Source
/// literals and HTML blocks are escaped by default. Raw HTML and comment
/// preservation require explicit options. Hook output is a caller trust boundary.
public struct HTMLRenderer: Sendable {
    public let includeSourceRanges: Bool
    public let allowRawHTML: Bool
    public let preserveHTMLComments: Bool
    private let hooks: [NodeKind: HTMLRendererHook]

    public init(includeSourceRanges: Bool = false, allowRawHTML: Bool = false,
                preserveHTMLComments: Bool = false, hooks: [NodeKind: HTMLRendererHook] = [:]) {
        self.includeSourceRanges = includeSourceRanges
        self.allowRawHTML = allowRawHTML
        self.preserveHTMLComments = preserveHTMLComments
        self.hooks = hooks
    }

    private enum Event { case enter(Int, tightItem: Bool = false), output(String) }

    public func render(_ document: Document) -> String {
        var output = ""
        var pending: [Event] = [.enter(0)]
        while let event = pending.popLast() {
            switch event {
            case .output(let text): output += text
            case .enter(let index, let tightItem):
                let node = document.nodes[index]
                if let directive = hooks[node.kind]?(node, document) {
                    switch directive {
                    case .replace(let html): output += html
                    case .wrapChildren(let open, let close):
                        output += open
                        pending.append(.output(close))
                        scheduleChildren(index, document: document, pending: &pending)
                    }
                    continue
                }
                switch node.data {
                case .document:
                    scheduleChildren(index, document: document, pending: &pending)
                case .paragraph:
                    if !tightItem {
                        output += "<p\(anchors(node))>"
                        pending.append(.output("</p>\n"))
                    }
                    scheduleChildren(index, document: document, pending: &pending)
                case .blockQuote:
                    output += "<blockquote\(anchors(node))>\n"
                    pending.append(.output("</blockquote>\n"))
                    scheduleChildren(index, document: document, pending: &pending)
                case .list(let attributes):
                    let tag: String
                    switch attributes.style {
                    case .bullet: tag = "ul"; output += "<ul\(anchors(node))>\n"
                    case .ordered(let start, _):
                        tag = "ol"
                        let startAttribute = start == 1 ? "" : " start=\"\(start)\""
                        output += "<ol\(startAttribute)\(anchors(node))>\n"
                    }
                    pending.append(.output("</\(tag)>\n"))
                    for child in document.children(of: index).reversed() {
                        pending.append(.enter(child, tightItem: attributes.isTight))
                    }
                case .listItem:
                    let children = document.children(of: index).filter { document.nodes[$0].kind != .referenceDefinition }
                    output += "<li\(anchors(node))>"
                    if let first = children.first, !tightItem || document.nodes[first].kind != .paragraph { output += "\n" }
                    pending.append(.output("</li>\n"))
                    for (position, child) in children.enumerated().reversed() {
                        let unwrapped = tightItem && document.nodes[child].kind == .paragraph
                        if unwrapped && position + 1 < children.count { pending.append(.output("\n")) }
                        pending.append(.enter(child, tightItem: unwrapped))
                    }
                case .heading(let level):
                    output += "<h\(level)\(anchors(node))>"
                    pending.append(.output("</h\(level)>\n"))
                    scheduleChildren(index, document: document, pending: &pending)
                case .text(let text): output += Self.escape(text)
                case .softBreak: output += "\n"
                case .thematicBreak: output += "<hr\(anchors(node)) />\n"
                case .codeBlock(let info, let literal):
                    output += "<pre\(anchors(node))><code"
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
                        // Unknown leaf extensions retain escaped source text.
                        let bytes = document.source[node.range.lowerBound..<node.range.upperBound]
                        output += Self.escape(String(decoding: bytes, as: UTF8.self))
                    }
                }
            }
        }
        return output
    }

    private func scheduleChildren(_ index: Int, document: Document, pending: inout [Event]) {
        for child in document.children(of: index).reversed() { pending.append(.enter(child)) }
    }

    private func anchors(_ node: Node) -> String {
        includeSourceRanges ? " data-source-start=\"\(node.range.lowerBound)\" data-source-end=\"\(node.range.upperBound)\"" : ""
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
