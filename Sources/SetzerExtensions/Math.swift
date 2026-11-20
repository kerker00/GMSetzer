public import SetzerSyntax
public import SetzerParser

/// Opaque TeX from a document snapshot. This extension recognises syntax;
/// callers select a TeX renderer, its configuration and presentation policy.
public struct Math: Hashable, Sendable {
    public enum Format: String, Hashable, Sendable { case inline, display, fenced }
    public static let identifier = "math"
    public static let inlineKind = NodeKind("math.inline")
    public static let blockKind = NodeKind("math.block")

    public static let implementation = MarkdownExtension(identifier,
        nodeKinds: [inlineKind, blockKind], blockRules: [
            BlockRule("display", trigger: 36, interruptsParagraph: true, match: display),
        ], inlineRules: [
            InlineRule("inline", trigger: 36, prepare: { document in
                // Every eligible opener gets a next-close entry independently.
                // Dollars consumed by core code/HTML cannot steal other pairs.
                let pairs = inlinePairs(document.source)
                return { context in
                    guard let opening = context.originalRanges(for: SourceRange(context.offset, context.offset + 1))?.first,
                          let closing = pairs[opening.lowerBound] else { return nil }
                    let consumed = closing - opening.lowerBound + 1
                    let end = context.offset + consumed
                    guard end <= context.input.count,
                          context.originalRanges(for: SourceRange(context.offset, end)) == [SourceRange(opening.lowerBound, closing + 1)] else { return nil }
                    let content = SourceRange(context.offset + 1, end - 1)
                    let tex = repaired(context.input[content.lowerBound..<content.upperBound])
                    return InlineMatch(consumed: consumed, data: data(.inline, tex: tex), tokens: [
                        BlockToken("math.fence.open", range: SourceRange(context.offset, context.offset + 1)),
                        BlockToken("math.content", range: content),
                        BlockToken("math.fence.close", range: SourceRange(end - 1, end)),
                    ])
                }
            }),
        ], postInlineTransforms: [BlockTransform("fenced", transform: fenced)])

    public let format: Format
    public var isDisplay: Bool { format != .inline }
    public let range: SourceRange
    /// Original TeX provenance, excluding delimiters and container prefixes.
    /// Partial tabs retain their source byte, independently of projected text.
    public let contentRanges: [SourceRange]
    public let rawBytes: [UInt8]
    /// Projected TeX: LF line endings, replacement UTF-8/NUL, no Markdown
    /// escape/entity decoding. Fenced content follows core code normalization.
    public let tex: String

    public init?(_ document: Document, at index: Int) {
        guard document.nodes.indices.contains(index) else { return nil }
        let node = document.nodes[index]
        guard case .custom(let kind, let role, let attributes) = node.data, node.firstChild == nil,
              case .string(let name) = attributes["format"], let format = Format(rawValue: name),
              case .string(let tex) = attributes["tex"] else { return nil }
        let ranges: [SourceRange]
        if format == .inline {
            guard kind == Self.inlineKind, role == .inline, node.range.count >= 3,
                  node.sourceSegments == [node.range] else { return nil }
            ranges = [SourceRange(node.range.lowerBound + 1, node.range.upperBound - 1)]
        } else {
            guard kind == Self.blockKind, role == .block else { return nil }
            ranges = node.sourceSegments
        }
        self.format = format; self.tex = tex; self.range = node.range
        self.contentRanges = ranges
        self.rawBytes = ranges.flatMap { Array(document.source[$0.lowerBound..<$0.upperBound]) }
    }

    private static func data(_ format: Format, tex: String) -> NodeData {
        .custom(kind: format == .inline ? inlineKind : blockKind,
            role: format == .inline ? .inline : .block,
            attributes: ["format": .string(format.rawValue), "tex": .string(tex)])
    }

    private struct Candidate {
        let offset: Int
        let canOpen: Bool
        let canClose: Bool
    }

    private static func inlinePairs(_ source: [UInt8]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var candidates: [Candidate] = []
        func finishLine() {
            var closing: Int?
            for candidate in candidates.reversed() {
                if candidate.canOpen, let closing { result[candidate.offset] = closing }
                if candidate.canClose { closing = candidate.offset }
            }
            candidates.removeAll(keepingCapacity: true)
        }
        var offset = 0, slashes = 0
        while offset < source.count {
            let byte = source[offset]
            if byte == 10 || byte == 13 { finishLine(); slashes = 0; offset += 1; continue }
            if byte == 92 { slashes += 1; offset += 1; continue }
            if byte == 36 {
                let start = offset
                repeat { offset += 1 } while offset < source.count && source[offset] == 36
                if offset - start == 1 && slashes % 2 == 0 {
                    let after = offset < source.count ? source[offset] : nil
                    candidates.append(Candidate(offset: start,
                        canOpen: !whitespace(source, at: offset),
                        canClose: !whitespaceBefore(source, at: start)
                            && !(after.map { (48...57).contains($0) } ?? false)))
                }
            } else { offset += 1 }
            slashes = 0
        }
        finishLine()
        return result
    }

    private static func whitespace(_ source: [UInt8], at offset: Int) -> Bool {
        guard offset < source.count else { return true }
        let byte = source[offset]
        if byte < 128 { return byte == 32 || (9...13).contains(byte) }
        var end = offset + 1
        while end < source.count && end - offset < 4 && source[end] & 0xC0 == 0x80 { end += 1 }
        return String(decoding: source[offset..<end], as: UTF8.self).unicodeScalars.first?.properties.isWhitespace == true
    }

    private static func whitespaceBefore(_ source: [UInt8], at offset: Int) -> Bool {
        guard offset > 0 else { return true }
        var start = offset - 1
        while start > 0 && offset - start < 4 && source[start] & 0xC0 == 0x80 { start -= 1 }
        return whitespace(source, at: start)
    }

    private static func repaired(_ bytes: ArraySlice<UInt8>) -> String {
        guard bytes.contains(0) else { return String(decoding: bytes, as: UTF8.self) }
        var output: [UInt8] = []
        for byte in bytes {
            if byte == 0 { output.append(contentsOf: [0xEF, 0xBF, 0xBD]) }
            else { output.append(byte) }
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// At most three indentation columns, using the current container view.
    private static func unindented(_ line: SourceLine, context: BlockContext) -> (SourceLine, Int)? {
        for columns in 0...3 {
            if let projected = context.droppingIndentation(columns, from: line),
               projected.virtualIndentation == 0,
               projected.contentRange.count >= 2,
               context.source[projected.contentRange.lowerBound] == 36,
               context.source[projected.contentRange.lowerBound + 1] == 36 { return (projected, columns) }
        }
        return nil
    }

    private static func bareFence(_ line: SourceLine, context: BlockContext) -> SourceRange? {
        guard let (line, _) = unindented(line, context: context) else { return nil }
        let start = line.contentRange.lowerBound
        guard context.source[(start + 2)..<line.contentRange.upperBound].allSatisfy({ $0 == 32 || $0 == 9 }) else { return nil }
        return SourceRange(start, start + 2)
    }

    private static func display(_ context: BlockContext) -> BlockMatch? {
        guard let (opening, indent) = unindented(context.line, context: context) else { return nil }
        let source = context.source
        let start = opening.contentRange.lowerBound
        let end = opening.contentRange.upperBound
        let open = SourceRange(start, start + 2)
        // One-line display blocks require two separate, exact-width fences.
        if end > start + 4, source[start + 2] != 36 {
            var last = end
            while last > start + 2 && (source[last - 1] == 32 || source[last - 1] == 9) { last -= 1 }
            if last >= start + 5, source[last - 1] == 36, source[last - 2] == 36,
               source[last - 3] != 36, !escaped(source, at: last - 2) {
                let content = SourceRange(start + 2, last - 2)
                return displayMatch(lines: 1, tex: repaired(source[content.lowerBound..<content.upperBound]),
                    segments: [content], open: open, close: SourceRange(last - 2, last))
            }
        }
        guard bareFence(opening, context: context) != nil else { return nil }
        var next = context.lineIndex + 1
        var tex = ""
        var segments: [SourceRange] = []
        while let line = context.line(at: next) {
            if let close = bareFence(line, context: context) {
                if segments.isEmpty { segments = [SourceRange(context.line.range.upperBound, context.line.range.upperBound)] }
                return displayMatch(lines: next - context.lineIndex + 1, tex: tex,
                    segments: segments, open: open, close: close)
            }
            var content = line
            for columns in stride(from: indent, through: 0, by: -1) {
                if let stripped = context.droppingIndentation(columns, from: line) { content = stripped; break }
            }
            tex += String(repeating: " ", count: content.virtualIndentation)
            tex += repaired(source[content.contentRange.lowerBound..<content.contentRange.upperBound])
            if content.range.upperBound > content.contentRange.upperBound { tex += "\n" }
            segments.append(content.range)
            next += 1
        }
        return nil
    }

    private static func escaped(_ source: [UInt8], at offset: Int) -> Bool {
        var cursor = offset
        while cursor > 0 && source[cursor - 1] == 92 { cursor -= 1 }
        return (offset - cursor) % 2 == 1
    }

    private static func displayMatch(lines: Int, tex: String, segments: [SourceRange],
                                     open: SourceRange, close: SourceRange) -> BlockMatch {
        BlockMatch(consumedLines: lines, data: data(.display, tex: tex), sourceSegments: segments,
            tokens: [BlockToken("math.fence.open", range: open)]
                + segments.map { BlockToken("math.content", range: $0) }
                + [BlockToken("math.fence.close", range: close)])
    }

    private static func fenced(_ document: Document) throws -> Document {
        var nodes = document.nodes
        var fallbacks = document.customLeafFallbacks
        var converted = Set<Int>()
        var tokens = document.tokens
        for (index, node) in document.nodes.enumerated() {
            guard case .codeBlock(let info, let literal) = node.data,
                  info?.split(whereSeparator: { $0 == " " || $0 == "\t" }).first == "math" else { continue }
            var segments = node.sourceSegments
            if segments.isEmpty {
                var insertion = node.range.lowerBound
                while insertion < node.range.upperBound && document.source[insertion] != 10 && document.source[insertion] != 13 { insertion += 1 }
                if insertion < node.range.upperBound {
                    let cr = document.source[insertion] == 13
                    insertion += 1
                    if cr && insertion < node.range.upperBound && document.source[insertion] == 10 { insertion += 1 }
                }
                segments = [SourceRange(insertion, insertion)]
            }
            nodes[index] = Node(data: data(.fenced, tex: literal), range: node.range,
                sourceSegments: segments, nextSibling: node.nextSibling)
            fallbacks[index] = literal
            converted.insert(index)
            if tokens != nil {
                for segment in segments { tokens?.append(SyntaxToken("math.content", range: segment, owner: index)) }
            }
        }
        // Retain existing core annotations verbatim; add namespaced aliases.
        if tokens != nil {
            for token in document.tokens ?? [] where converted.contains(token.owner) {
                let role: String
                switch token.role {
                case "core.fence.open": role = "math.fence.open"
                case "core.fence.info": role = "math.fence.info"
                case "core.fence.close": role = "math.fence.close"
                default: continue
                }
                tokens?.append(SyntaxToken(role, range: token.range, owner: token.owner))
            }
        }
        return try Document(source: document.source, nodes: nodes, diagnostics: document.diagnostics,
            customLeafFallbacks: fallbacks, tokens: tokens, renderingPolicy: document.renderingPolicy)
    }
}
