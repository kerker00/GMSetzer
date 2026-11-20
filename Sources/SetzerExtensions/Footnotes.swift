public import SetzerSyntax
public import SetzerParser

/// Opt-in named footnotes. Definitions retain parsed Markdown children;
/// numbering and HTML presentation never move nodes away from their source.
public enum Footnotes {
    public static let identifier = "footnotes"
    public static let definitionKind = NodeKind("footnotes.definition")
    public static let referenceKind = NodeKind("footnotes.reference")

    public static let implementation = MarkdownExtension(identifier,
        nodeKinds: [definitionKind, referenceKind], blockRules: [
            BlockRule("definition", trigger: 91, interruptsParagraph: true, match: definition),
        ], inlineRules: [
            InlineRule("reference", trigger: 91, allowsBracketSyntax: true, prepare: { document in
                let definitions = definitionLookup(document)
                return { context in
                    guard let label = label(in: context.input, at: context.offset, end: context.input.count),
                          definitions[InlineDecoding.label(label.raw)] != nil else { return nil }
                    let start = context.offset
                    return InlineMatch(consumed: label.end - start,
                        data: .custom(kind: referenceKind, role: .inline, attributes: ["label": .string(label.raw)]),
                        tokens: [BlockToken("footnotes.reference.open", range: SourceRange(start, start + 2)),
                            BlockToken("footnotes.reference.label", range: SourceRange(start + 2, label.end - 1)),
                            BlockToken("footnotes.reference.close", range: SourceRange(label.end - 1, label.end))])
                }
            }),
        ], postInlineTransforms: [BlockTransform("number", transform: numbered)])

    /// A cited definition and all of its reachable calls, in display order.
    public struct Note: Hashable, Sendable {
        public let number: Int
        public let definition: Int
        public fileprivate(set) var references: [Int]
    }

    /// Snapshot-bound node indices. Body references determine order, followed
    /// by references in cited notes. Each definition body is visited once;
    /// cycles cannot recursively expand the document.
    public struct Index: Hashable, Sendable {
        public let notes: [Note]

        public init(_ document: Document) {
            let definitions = definitionLookup(document)
            var notes: [Note] = []
            var positions: [Int: Int] = [:]
            func visit(_ parent: Int) {
                var pending = document.children(of: parent).reversed().map { $0 }
                while let index = pending.popLast() {
                    let node = document.nodes[index]
                    if node.kind == definitionKind { continue }
                    if let raw = rawLabel(node, kind: referenceKind, role: .inline),
                       let definition = definitions[InlineDecoding.label(raw)] {
                        let position: Int
                        if let existing = positions[definition] { position = existing }
                        else {
                            position = notes.count
                            positions[definition] = position
                            notes.append(Note(number: position + 1, definition: definition, references: []))
                        }
                        notes[position].references.append(index)
                    }
                    pending.append(contentsOf: document.children(of: index).reversed())
                }
            }
            visit(0)
            var next = 0
            while next < notes.count { visit(notes[next].definition); next += 1 }
            self.notes = notes
        }
    }

    /// Source spelling, without decoding escapes/entities or applying locale.
    public static func label(_ node: Node) -> String? {
        rawLabel(node, kind: definitionKind, role: .block)
            ?? rawLabel(node, kind: referenceKind, role: .inline)
    }

    private static func rawLabel(_ node: Node, kind: NodeKind, role: NodeRole) -> String? {
        guard case .custom(kind, role, let attributes) = node.data,
              case .string(let raw) = attributes["label"] else { return nil }
        return raw
    }

    private static func definitionLookup(_ document: Document) -> [ReferenceLabel: Int] {
        var definitions: [ReferenceLabel: Int] = [:]
        var pending = document.children(of: 0).reversed().map { $0 }
        while let index = pending.popLast() {
            if let raw = rawLabel(document.nodes[index], kind: definitionKind, role: .block) {
                let key = InlineDecoding.label(raw)
                if definitions[key] == nil { definitions[key] = index }
            }
            pending.append(contentsOf: document.children(of: index).reversed())
        }
        return definitions
    }

    private struct Label {
        let raw: String
        let end: Int
    }

    /// A bounded scan also limits repeated failed attempts on hostile input.
    /// Labels contain 1...999 scalars, no ASCII whitespace or unescaped brackets.
    private static func label(in bytes: [UInt8], at start: Int, end: Int) -> Label? {
        guard start + 3 < end, bytes[start] == 91, bytes[start + 1] == 94 else { return nil }
        var cursor = start + 2
        while cursor < end && cursor - start <= 3998 {
            let byte = bytes[cursor]
            if byte == 93 {
                let raw = String(decoding: bytes[(start + 2)..<cursor], as: UTF8.self)
                guard !raw.isEmpty, raw.unicodeScalars.count <= 999 else { return nil }
                return Label(raw: raw, end: cursor + 1)
            }
            if byte <= 32 || byte == 127 || byte == 91 { return nil }
            if byte == 92, cursor + 1 < end, [UInt8(91), 92, 93].contains(bytes[cursor + 1]) { cursor += 2 }
            else { cursor += 1 }
        }
        return nil
    }

    private static func definition(_ context: BlockContext) -> BlockMatch? {
        let source = context.source
        var opening: SourceLine?
        for columns in 0...3 {
            if let line = context.droppingIndentation(columns, from: context.line),
               line.virtualIndentation == 0, line.contentRange.lowerBound < line.contentRange.upperBound,
               source[line.contentRange.lowerBound] == 91 { opening = line; break }
        }
        guard let opening,
              let label = label(in: source, at: opening.contentRange.lowerBound, end: opening.contentRange.upperBound),
              label.end < opening.contentRange.upperBound, source[label.end] == 58,
              let afterMarker = context.droppingBytes(label.end + 1 - opening.contentRange.lowerBound, from: opening) else { return nil }
        var first = afterMarker
        for columns in stride(from: 4, through: 0, by: -1) {
            if let stripped = context.droppingIndentation(columns, from: afterMarker) { first = stripped; break }
        }
        var children = [first]
        var next = context.lineIndex + 1
        while let line = context.line(at: next) {
            if source[line.contentRange.lowerBound..<line.contentRange.upperBound].allSatisfy({ $0 == 32 || $0 == 9 }) {
                children.append(line)
            } else if let stripped = context.droppingIndentation(4, from: line) {
                children.append(stripped)
            } else { break }
            next += 1
        }
        let start = opening.contentRange.lowerBound
        return BlockMatch(consumedLines: next - context.lineIndex,
            data: .custom(kind: definitionKind, role: .block, attributes: ["label": .string(label.raw)]),
            children: children, tokens: [
                BlockToken("footnotes.definition.open", range: SourceRange(start, start + 2)),
                BlockToken("footnotes.definition.label", range: SourceRange(start + 2, label.end - 1)),
                BlockToken("footnotes.definition.close", range: SourceRange(label.end - 1, label.end + 1)),
            ])
    }

    private static func numbered(_ document: Document) throws -> Document {
        let index = Index(document)
        var nodes = document.nodes
        func update(_ position: Int, number: Int, occurrence: Int? = nil) {
            let node = nodes[position]
            guard case .custom(let kind, let role, var attributes) = node.data else { return }
            attributes["number"] = .integer(number)
            if let occurrence { attributes["occurrence"] = .integer(occurrence) }
            nodes[position] = Node(data: .custom(kind: kind, role: role, attributes: attributes), range: node.range,
                sourceSegments: node.sourceSegments, firstChild: node.firstChild, nextSibling: node.nextSibling)
        }
        for note in index.notes {
            update(note.definition, number: note.number)
            for (occurrence, reference) in note.references.enumerated() {
                update(reference, number: note.number, occurrence: occurrence + 1)
            }
        }
        return try Document(source: document.source, nodes: nodes, diagnostics: document.diagnostics,
            customLeafFallbacks: document.customLeafFallbacks, tokens: document.tokens,
            renderingPolicy: document.renderingPolicy)
    }
}
