public import SetzerSyntax

/// Parses CommonMark blocks and inlines over an immutable UTF-8 snapshot.
/// Optional lexical tokens retain source spelling; native analysis follows in M3.
public struct MarkdownParser: Sendable {
    public let profile: Profile
    internal let registry: RuleRegistry
    internal var resolvedTransforms: [ActiveTransform] { registry.transforms }
    internal var resolvedInlineRules: [ActiveInlineRule] { registry.inlineRules }
    internal var resolvedPostInlineTransforms: [ActiveTransform] { registry.postInlineTransforms }
    public var configurationIssues: [ConfigurationIssue] { registry.issues }
    public let limits: ParserLimits
    public let collectSyntaxDetails: Bool

    public init(profile: Profile = .commonMark, extensions: [MarkdownExtension] = [], limits: ParserLimits = ParserLimits(),
                collectSyntaxDetails: Bool = false) {
        self.profile = profile
        self.registry = RuleRegistry(profile: profile, extensions: extensions)
        self.limits = limits
        self.collectSyntaxDetails = collectSyntaxDetails
    }

    /// Strict consumers can reject configuration; tolerant consumers still get
    /// a deterministic core/literal parse and inspect configurationIssues once.
    public func validated() throws -> MarkdownParser {
        if !configurationIssues.isEmpty { throw ConfigurationError(configurationIssues) }
        return self
    }

    public func parse(_ text: String) -> Document { parse(bytes: Array(text.utf8)) }

    /// Keeps original bytes, including malformed UTF-8. Literals use Swift's
    /// UTF-8 replacement decoding; NUL becomes U+FFFD. A leading UTF-8 BOM is
    /// ignored as syntax, but remains in the source and its original offsets.
    public func parse(bytes: [UInt8]) -> Document {
        var parser = BlockParser(source: bytes, registry: registry, limits: limits,
                                 collectSyntaxDetails: collectSyntaxDetails)
        let document = applyTransforms(to: parseInlines(applyTransforms(to: parser.parse())), afterInlines: true)
        let policy = registry.renderingPolicy
        return policy.isEmpty ? document : document.with(renderingPolicy: policy)
    }
}

internal struct ActiveRule: Sendable {
    let rule: BlockRule
    let options: [String: SyntaxValue]
    let order: Int
    let descriptor: ExtensionDescriptor
    let identifier: String
}

internal struct BlockParser {
    let source: [UInt8]
    /// One table for physical and projected lines. Line `i` is replaced by
    /// its projection only when the main loop reaches it, and the loop never
    /// revisits a line, so every later entry is still the physical line.
    /// A single table avoids copying all lines on the first projection.
    var lines: [SourceLine]
    let limits: ParserLimits
    let collectSyntaxDetails: Bool
    let extensionDepth: Int
    var containers: [OpenContainer] = []
    var leaf: OpenLeaf?
    /// Line whose remaining content must start a paragraph (after a GFM
    /// task list checkbox); no other leaf start is tried there.
    var forcedParagraphLine = -1
    /// GFM: the last paragraph line added lazily. cmark-gfm keeps such a line
    /// from the end of the matched containers, so a table header there keeps
    /// its leading whitespace.
    var lazyParagraphLine = -1
    /// State of the open GFM table leaf, if any.
    var openTable: TableState?
    var builder: DocumentBuilder
    let registry: RuleRegistry
    var rules: [ActiveRule] { registry.custom }

    init(source: [UInt8], registry: RuleRegistry, limits: ParserLimits, collectSyntaxDetails: Bool,
         projectedLines: [SourceLine]? = nil, extensionDepth: Int = 0) {
        self.source = source
        self.lines = projectedLines ?? Self.scanLines(source)
        self.extensionDepth = extensionDepth
        self.limits = limits
        self.collectSyntaxDetails = collectSyntaxDetails
        self.builder = DocumentBuilder(source: source, collectSyntaxDetails: collectSyntaxDetails)
        // Typical documents have one to two nodes per line. Reserving one and
        // a half per line avoids regrowth there; array doubling would keep at
        // least as much spare capacity.
        self.builder.reserveCapacity(lines.count + lines.count / 2 + 1)
        self.registry = registry
    }

    @discardableResult
    @inline(__always)
    mutating func append(_ data: consuming NodeData, range: SourceRange, segments: [SourceRange],
                         fallbackLiteral: String? = nil, to parent: Int? = nil) -> Int {
        append(data, range: range, segments: SourceSegments(segments), fallbackLiteral: fallbackLiteral, to: parent)
    }

    @discardableResult
    @inline(__always)
    mutating func append(_ data: consuming NodeData, range: SourceRange, segments: SourceSegments = .none,
                         fallbackLiteral: String? = nil, to parent: Int? = nil) -> Int {
        // M1-D audit: parent is root, a previously appended open container, or
        // a just-appended leaf/import parent. Callbacks cannot supply indices.
        // A failure is a parser defect; do not silently replace its snapshot.
        try! builder.append(data, range: range, segments: segments, fallbackLiteral: fallbackLiteral,
                            to: parent ?? containers.last?.node ?? 0)
    }

    mutating func appendText(_ range: SourceRange, to parent: Int) {
        if !range.isEmpty { append(.text(decode(range)), range: range, segments: .one(range), to: parent) }
    }

    static func scanLines(_ bytes: [UInt8]) -> [SourceLine] {
        var result: [SourceLine] = []
        bytes.withUnsafeBufferPointer { buffer in
            let count = buffer.count
            // One pass counts line terminators so the line table is allocated
            // exactly once; the second pass records the lines.
            result.reserveCapacity(LineTerminators.count(in: buffer) + 1)
            var start = 0
            var cursor = 0
            while let found = LineTerminators.next(in: buffer, from: cursor) {
                cursor = found
                let contentEnd = cursor
                if buffer[cursor] == 13 && cursor + 1 < count && buffer[cursor + 1] == 10 { cursor += 1 }
                cursor += 1
                result.append(SourceLine(start, contentEnd, cursor))
                start = cursor
            }
            if start < count { result.append(SourceLine(start, count, count)) }
        }
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]), let first = result.first {
            // Keep physicalRange at byte zero, but begin syntax recognition
            // after the BOM with a fresh column for indentation/tab stops.
            result[0] = SourceLine(original: first, offset: 3, column: 0, virtual: 0, virtualSourceOffset: nil)
        }
        return result
    }

    func space(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 }
    func punctuation(_ byte: UInt8) -> Bool {
        (33...47).contains(byte) || (58...64).contains(byte) ||
        (91...96).contains(byte) || (123...126).contains(byte)
    }
    func isBlank(_ index: Int) -> Bool {
        let range = lines[index].contentRange
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            let byte = source[cursor]
            if byte != 32 && byte != 9 { return false }
            cursor += 1
        }
        return true
    }

    @inline(__always)
    func indentation(_ index: Int) -> (offset: Int, columns: Int) {
        indentation(of: lines[index])
    }

    @inline(__always)
    func indentation(of line: SourceLine) -> (offset: Int, columns: Int) {
        var cursor = SourceCursor(line: line)
        let columns = cursor.skipIndentation(in: source)
        return (cursor.offset, columns)
    }

    func trimmed(_ start: Int, _ end: Int) -> SourceRange {
        var lower = start
        var upper = end
        while lower < upper && space(source[lower]) { lower += 1 }
        while upper > lower && space(source[upper - 1]) { upper -= 1 }
        return SourceRange(lower, upper)
    }

    func decode(_ range: SourceRange) -> String {
        source.withUnsafeBufferPointer { buffer in
            let bytes = UnsafeBufferPointer(rebasing: buffer[range.lowerBound..<range.upperBound])
            if !ByteSearch.containsZero(bytes) { return String(decoding: bytes, as: UTF8.self) }
            var repaired: [UInt8] = []
            repaired.reserveCapacity(bytes.count + 8)
            Self.appendRepaired(bytes, to: &repaired)
            return String(decoding: repaired, as: UTF8.self)
        }
    }

    /// Append original bytes with NUL replaced by U+FFFD. Multi-line literals
    /// collect bytes first and decode once; ASCII separators between lines
    /// end any malformed sequence exactly as separate decoding would.
    @inline(__always)
    static func appendRepaired(_ bytes: UnsafeBufferPointer<UInt8>, to output: inout [UInt8]) {
        var runStart = 0
        for position in 0..<bytes.count where bytes[position] == 0 {
            output.append(contentsOf: UnsafeBufferPointer(rebasing: bytes[runStart..<position]))
            output.append(0xEF); output.append(0xBF); output.append(0xBD)
            runStart = position + 1
        }
        output.append(contentsOf: UnsafeBufferPointer(rebasing: bytes[runStart..<bytes.count]))
    }

    func appendRepaired(_ range: SourceRange, to output: inout [UInt8]) {
        source.withUnsafeBufferPointer { buffer in
            Self.appendRepaired(UnsafeBufferPointer(rebasing: buffer[range.lowerBound..<range.upperBound]), to: &output)
        }
    }

    @inline(__always)
    static func appendSpaces(_ count: Int, to output: inout [UInt8]) {
        for _ in 0..<count { output.append(32) }
    }

    func atxHeading(_ index: Int) -> (level: Int, content: SourceRange)? {
        let indent = indentation(index)
        guard indent.columns <= 3 else { return nil }
        let end = lines[index].contentRange.upperBound
        var cursor = indent.offset
        while cursor < end && source[cursor] == 35 { cursor += 1 }
        let level = cursor - indent.offset
        guard (1...6).contains(level), cursor == end || space(source[cursor]) else { return nil }
        let content = trimmed(cursor, end)
        var closing = content.upperBound
        while closing > content.lowerBound && source[closing - 1] == 35 { closing -= 1 }
        if closing < content.upperBound && (closing == content.lowerBound || space(source[closing - 1])) {
            return (level, trimmed(content.lowerBound, closing))
        }
        return (level, content)
    }

    func setextLevel(_ index: Int) -> Int? {
        let indent = indentation(index)
        guard indent.columns <= 3 else { return nil }
        let content = trimmed(indent.offset, lines[index].contentRange.upperBound)
        guard !content.isEmpty else { return nil }
        let marker = source[content.lowerBound]
        guard marker == 61 || marker == 45,
              source[content.lowerBound..<content.upperBound].allSatisfy({ $0 == marker }) else { return nil }
        return marker == 61 ? 1 : 2
    }

    func thematicBreak(_ index: Int) -> Bool {
        let indent = indentation(index)
        guard indent.columns <= 3, indent.offset < lines[index].contentRange.upperBound else { return false }
        let marker = source[indent.offset]
        guard marker == 42 || marker == 45 || marker == 95 else { return false }
        var count = 0
        for byte in source[indent.offset..<lines[index].contentRange.upperBound] {
            if byte == marker { count += 1 }
            else if !space(byte) { return false }
        }
        return count >= 3
    }

    /// The info string stays a source range until the block is finished,
    /// so an open leaf holds no reference-counted storage.
    struct Fence { let marker: UInt8; let count: Int; let indent: Int; let info: SourceRange? }

    func openingFence(_ index: Int) -> Fence? {
        let indent = indentation(index)
        let end = lines[index].contentRange.upperBound
        guard indent.columns <= 3, indent.offset < end else { return nil }
        let marker = source[indent.offset]
        guard marker == 96 || marker == 126 else { return nil }
        var cursor = indent.offset
        while cursor < end && source[cursor] == marker { cursor += 1 }
        guard cursor - indent.offset >= 3 else { return nil }
        let info = trimmed(cursor, end)
        if marker == 96 && source[info.lowerBound..<info.upperBound].contains(96) { return nil }
        return Fence(marker: marker, count: cursor - indent.offset, indent: indent.columns,
                     info: info.isEmpty ? nil : info)
    }

    func closesFence(_ index: Int, _ fence: Fence) -> Bool {
        let indent = indentation(index)
        guard indent.columns <= 3 else { return false }
        let end = lines[index].contentRange.upperBound
        var cursor = indent.offset
        while cursor < end && source[cursor] == fence.marker { cursor += 1 }
        return cursor - indent.offset >= fence.count && source[cursor..<end].allSatisfy(space)
    }

    /// Original source segments include a partially consumed tab byte.
    func appendCodeContent(_ index: Int, removing columns: Int, to literal: inout [UInt8]) -> SourceRange {
        let line = lines[index]
        var cursor = SourceCursor(line: line)
        cursor.consumeIndentation(columns, in: source)
        Self.appendSpaces(cursor.virtual, to: &literal)
        appendRepaired(SourceRange(cursor.offset, line.contentRange.upperBound), to: &literal)
        literal.append(10)
        return SourceRange(cursor.virtual > 0 ? (cursor.virtualSourceOffset ?? cursor.offset) : cursor.offset, line.range.upperBound)
    }

    mutating func extensionMatch(at index: Int, interrupting: Bool, prefixCount: Int? = nil, candidate: ActiveRule? = nil)
        -> (match: BlockMatch, lines: [SourceLine])? {
        let indent = indentation(index)
        guard indent.columns <= 3 else { return nil }
        let first = indent.offset
        if candidate == nil {
            for active in rules {
                if let match = extensionMatch(at: index, interrupting: interrupting, prefixCount: prefixCount, candidate: active) { return match }
            }
            return nil
        }
        if let active = candidate {
            if interrupting && !active.rule.interruptsParagraph { return nil }
            if let trigger = active.rule.trigger,
               (first == lines[index].contentRange.upperBound || source[first] != trigger) { return nil }
            let source = self.source
            // Lines after `index` are still physical (see `lines`). The snapshot
            // shares storage and is released before the next projection.
            let physicalLines = self.lines
            let prefixes = containers.prefix(prefixCount ?? containers.count).map(\.prefix)
            let currentLine = lines[index]
            let context = BlockContext(source: source, lineIndex: index,
                                       isDocumentStart: index == 0 && extensionDepth == 0 && containers.isEmpty,
                                       options: active.options,
                                       line: currentLine, lineCount: physicalLines.count, project: { target in
                guard target >= index && physicalLines.indices.contains(target) else { return nil }
                if target == index { return currentLine }
                return Self.project(physicalLines[target], source: source, prefixes: prefixes)
            })
            guard let match = active.rule.match(context) else { return nil }
            var valid = match.consumedLines > 0 && match.consumedLines <= lines.count - index
            if case .custom(let kind, .block, _) = match.data {
                valid = valid && active.descriptor.nodeKinds.contains(kind) && active.descriptor.owns(kind.name)
            } else { valid = false }
            var projected: [SourceLine] = []
            if valid {
                for target in index..<(index + match.consumedLines) {
                    guard let line = context.line(at: target) else { valid = false; break }
                    projected.append(line)
                }
            }
            if valid {
                let range = SourceRange(lines[index].range.lowerBound, lines[index + match.consumedLines - 1].range.upperBound)
                var previousEnd = range.lowerBound
                for segment in match.sourceSegments {
                    if !range.contains(segment) || segment.lowerBound < previousEnd { valid = false; break }
                    previousEnd = segment.upperBound
                }
            }
            if valid {
                let range = SourceRange(lines[index].range.lowerBound, lines[index + match.consumedLines - 1].range.upperBound)
                valid = match.tokens.allSatisfy { active.descriptor.owns($0.role) && range.contains($0.range) }
                    && match.diagnostics.allSatisfy {
                        if case .extensionFinding(let owner, _, _) = $0.code {
                            return owner == active.descriptor.identifier && range.contains($0.range)
                        }
                        return false
                    }
                if let children = match.children {
                    // Only suffix projections of this match's physical lines.
                    // Views can only be produced by core projection helpers.
                    var position = 0
                    for child in children {
                        while position < projected.count && projected[position].physicalRange != child.physicalRange { position += 1 }
                        guard position < projected.count,
                              projected[position].range.contains(child.range),
                              child.contentRange.upperBound == projected[position].contentRange.upperBound,
                              child.column >= projected[position].column else { valid = false; break }
                        position += 1
                    }
                }
            }
            if valid { return (match, projected) }
            builder.report(ParseDiagnostic(.invalidExtensionResult(active.identifier), range: lines[index].range))
        }
        return nil
    }

    /// Source segments describe semantic provenance, not a fallback literal:
    /// they may omit delimiters, line endings and virtual tab spaces.
    func extensionFallback(_ projected: [SourceLine]) -> String {
        var literal = ""
        for line in projected {
            literal += String(repeating: " ", count: line.virtualIndentation)
            literal += decode(line.contentRange)
            if line.range.upperBound > line.contentRange.upperBound { literal += "\n" }
        }
        return literal
    }
}

