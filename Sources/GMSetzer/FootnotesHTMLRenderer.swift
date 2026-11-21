import SetzerExtensions
public import SetzerHTML
public import SetzerSyntax

/// HTML presentation for opt-in footnotes. Definitions remain in source order
/// in the tree; this renderer appends only cited notes in reference order.
/// Available through the convenience product `GMSetzer`.
public struct FootnotesHTMLRenderer: Sendable {
    public let renderer: HTMLRenderer
    /// Namespace separate documents on one page. Only ASCII letters, digits,
    /// and `-` survive; other UTF-8 bytes are hex-encoded without collisions.
    public let idPrefix: String
    /// Callers may localise this plain-text accessible label.
    public let backlinkLabel: String

    public init(renderer: HTMLRenderer = HTMLRenderer(), idPrefix: String = "fn-",
                backlinkLabel: String = "Back to reference") {
        self.renderer = renderer; self.idPrefix = idPrefix; self.backlinkLabel = backlinkLabel
    }

    public func render(_ document: Document) -> String {
        let context = prepareContext(document)
        return context.renderer.render(document, tree: context.tree) + renderAppendix(document, context: context, checkpoint: {})
    }

    /// Number references once over the full document. The appendix remains a
    /// single insertable group and is generated only when requested.
    public func prepare(_ document: Document, maximumSourceBytesPerGroup: Int = 32_768) throws -> HTMLRenderPlan {
        guard maximumSourceBytesPerGroup > 0 else { throw HTMLRenderPlanError.invalidGroupSize }
        let context = prepareContext(document)
        let appendix: (@Sendable (_ checkpoint: () throws -> Void) throws -> String)?
        if context.notes.isEmpty { appendix = nil }
        else { appendix = { checkpoint in try renderAppendix(document, context: context, checkpoint: checkpoint) } }
        return try HTMLRenderPlan(document: document, renderer: context.renderer, tree: context.tree,
                                  maximumSourceBytesPerGroup: maximumSourceBytesPerGroup,
                                  omittingTopLevelKinds: [Footnotes.definitionKind], appendix: appendix)
    }

    private struct Context: Sendable {
        let notes: [Footnotes.Note]
        let prefix: String
        let renderer: HTMLRenderer
        let tree: DocumentIndex
    }

    private func prepareContext(_ document: Document) -> Context {
        let index = Footnotes.Index(document)
        let prefix = safePrefix(idPrefix)
        var references: [SourceRange: String] = [:]
        for note in index.notes {
            for (occurrence, reference) in note.references.enumerated() {
                let html = "<sup><a href=\"#\(prefix)note-\(note.number)\" id=\"\(prefix)ref-\(note.number)-\(occurrence + 1)\" data-footnote-ref=\"\">\(note.number)</a></sup>"
                references[document.nodes[reference].range] = html
            }
        }
        let renderedReferences = references
        let composed = renderer.addingHooks([
            Footnotes.definitionKind: { _, _ in .replace("") },
            Footnotes.referenceKind: { node, _ in renderedReferences[node.range].map { .replace($0) } },
        ], independent: true)
        return Context(notes: index.notes, prefix: prefix, renderer: composed, tree: DocumentIndex(document))
    }

    private func renderAppendix(_ document: Document, context: Context,
                                checkpoint: () throws -> Void) rethrows -> String {
        guard !context.notes.isEmpty else { return "" }
        let prefix = context.prefix
        var output = "<section class=\"footnotes\" data-footnotes=\"\">\n<ol>\n"
        for note in context.notes {
            try checkpoint()
            output += "<li id=\"\(prefix)note-\(note.number)\">\n"
            output += try context.renderer.renderChildren(document, of: note.definition, tree: context.tree, checkpoint: checkpoint)
            output += "<p>"
            for occurrence in 1...note.references.count {
                try checkpoint()
                if occurrence > 1 { output += " " }
                let label = HTMLRenderer.escape("\(backlinkLabel) \(note.number).\(occurrence)")
                output += "<a href=\"#\(prefix)ref-\(note.number)-\(occurrence)\" data-footnote-backref=\"\" aria-label=\"\(label)\">↩</a>"
            }
            output += "</p>\n</li>\n"
        }
        output += "</ol>\n</section>\n"
        return output
    }

    private func safePrefix(_ value: String) -> String {
        let hex = Array("0123456789abcdef".utf8)
        var bytes: [UInt8] = []
        for byte in value.utf8 {
            if (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 45 {
                bytes.append(byte)
            } else {
                bytes.append(95); bytes.append(hex[Int(byte >> 4)]); bytes.append(hex[Int(byte & 15)])
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
