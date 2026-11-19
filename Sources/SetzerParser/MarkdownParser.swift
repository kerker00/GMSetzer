public import SetzerSyntax

/// Parses CommonMark block structure, HTML blocks and reference definitions.
/// Inline markup and editor analysis follow; see Docs/SyntaxTree.md.
public struct MarkdownParser: Sendable {
    public let profile: Profile
    private let extensions: [MarkdownExtension]
    public let limits: ParserLimits
    public let collectSyntaxDetails: Bool

    public init(profile: Profile = .commonMark, extensions: [MarkdownExtension] = [], limits: ParserLimits = ParserLimits(),
                collectSyntaxDetails: Bool = false) {
        self.profile = profile
        self.extensions = extensions
        self.limits = limits
        self.collectSyntaxDetails = collectSyntaxDetails
    }

    public func parse(_ text: String) -> Document { parse(bytes: Array(text.utf8)) }

    /// Keeps original bytes, including malformed UTF-8. Literals use Swift's
    /// UTF-8 replacement decoding; NUL becomes U+FFFD. Source offsets never shift.
    public func parse(bytes: [UInt8]) -> Document {
        var parser = BlockParser(source: bytes, profile: profile, extensions: extensions, limits: limits,
                                 collectSyntaxDetails: collectSyntaxDetails)
        return parser.parse()
    }
}

internal struct ActiveRule {
    let rule: BlockRule
    let options: [String: SyntaxValue]
    let order: Int
}

internal struct BlockParser {
    let source: [UInt8]
    let physicalLines: [SourceLine]
    var lines: [SourceLine]
    let limits: ParserLimits
    let collectSyntaxDetails: Bool
    var containers: [OpenContainer] = []
    var leaf: OpenLeaf?
    var builder: DocumentBuilder
    var rules: [ActiveRule] = []

    init(source: [UInt8], profile: Profile, extensions: [MarkdownExtension], limits: ParserLimits, collectSyntaxDetails: Bool) {
        self.source = source
        self.physicalLines = Self.scanLines(source)
        self.lines = self.physicalLines
        self.limits = limits
        self.collectSyntaxDetails = collectSyntaxDetails
        self.builder = DocumentBuilder(source: source)
        var registry: [String: MarkdownExtension] = [:]
        for item in extensions {
            if registry[item.identifier] != nil {
                builder.report(ParseDiagnostic(.duplicateRegistration(item.identifier), range: SourceRange(0, 0)))
            } else { registry[item.identifier] = item }
        }
        var selected = Set<String>()
        for selection in profile.extensions {
            guard selected.insert(selection.identifier).inserted else {
                builder.report(ParseDiagnostic(.duplicateRegistration(selection.identifier), range: SourceRange(0, 0)))
                continue
            }
            guard let implementation = registry[selection.identifier] else {
                builder.report(ParseDiagnostic(.unsupportedExtension(selection.identifier), range: SourceRange(0, 0)))
                continue
            }
            var seen = Set<String>()
            for rule in implementation.blockRules {
                guard seen.insert(rule.identifier).inserted else {
                    builder.report(ParseDiagnostic(.duplicateRegistration(rule.identifier), range: SourceRange(0, 0)))
                    continue
                }
                rules.append(ActiveRule(rule: rule, options: selection.options, order: rules.count))
            }
        }
        rules.sort {
            $0.rule.priority == $1.rule.priority ? $0.order < $1.order : $0.rule.priority > $1.rule.priority
        }
    }

    @discardableResult
    mutating func append(_ data: NodeData, range: SourceRange, segments: [SourceRange] = [], to parent: Int? = nil) -> Int {
        try! builder.append(data, range: range, sourceSegments: segments, to: parent ?? containers.last?.node ?? 0)
    }

    mutating func appendText(_ range: SourceRange, to parent: Int) {
        if !range.isEmpty { append(.text(decode(range)), range: range, segments: [range], to: parent) }
    }

    static func scanLines(_ bytes: [UInt8]) -> [SourceLine] {
        var result: [SourceLine] = []
        var start = 0
        var cursor = 0
        while cursor < bytes.count {
            if bytes[cursor] == 10 || bytes[cursor] == 13 {
                let contentEnd = cursor
                if bytes[cursor] == 13 && cursor + 1 < bytes.count && bytes[cursor + 1] == 10 { cursor += 1 }
                cursor += 1
                result.append(SourceLine(start, contentEnd, cursor))
                start = cursor
            } else { cursor += 1 }
        }
        if start < bytes.count { result.append(SourceLine(start, bytes.count, bytes.count)) }
        return result
    }

    func space(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 }
    func punctuation(_ byte: UInt8) -> Bool {
        (33...47).contains(byte) || (58...64).contains(byte) ||
        (91...96).contains(byte) || (123...126).contains(byte)
    }
    func isBlank(_ index: Int) -> Bool { source[lines[index].contentRange.lowerBound..<lines[index].contentRange.upperBound].allSatisfy(space) }

    func indentation(_ index: Int) -> (offset: Int, columns: Int) {
        var cursor = SourceCursor(source: source, line: lines[index])
        let columns = cursor.skipIndentation()
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
        let bytes = source[range.lowerBound..<range.upperBound]
        if !bytes.contains(0) { return String(decoding: bytes, as: UTF8.self) }
        var repaired: [UInt8] = []
        for byte in bytes {
            if byte == 0 { repaired.append(contentsOf: [0xEF, 0xBF, 0xBD]) }
            else { repaired.append(byte) }
        }
        return String(decoding: repaired, as: UTF8.self)
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

    struct Fence { let marker: UInt8; let count: Int; let indent: Int; let info: String? }

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
                     info: info.isEmpty ? nil : decode(info))
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
    func codeContent(_ index: Int, removing columns: Int) -> (range: SourceRange, literal: String) {
        let line = lines[index]
        var cursor = SourceCursor(source: source, line: line)
        cursor.consumeIndentation(columns)
        return (SourceRange(cursor.view.range.lowerBound, line.range.upperBound),
                String(repeating: " ", count: cursor.virtual) + decode(SourceRange(cursor.offset, line.contentRange.upperBound)) + "\n")
    }

    mutating func extensionMatch(at index: Int, interrupting: Bool, prefixCount: Int? = nil) -> BlockMatch? {
        let indent = indentation(index)
        guard indent.columns <= 3 else { return nil }
        let first = indent.offset
        for active in rules {
            if interrupting && !active.rule.interruptsParagraph { continue }
            if let trigger = active.rule.trigger,
               (first == lines[index].contentRange.upperBound || source[first] != trigger) { continue }
            let source = self.source
            let physicalLines = self.physicalLines
            let prefixes = containers.prefix(prefixCount ?? containers.count).map(\.prefix)
            let currentLine = lines[index]
            let context = BlockContext(source: source, lineIndex: index, options: active.options,
                                       line: currentLine, lineCount: physicalLines.count, project: { target in
                guard target >= index && physicalLines.indices.contains(target) else { return nil }
                if target == index { return currentLine }
                return Self.project(physicalLines[target], source: source, prefixes: prefixes)
            })
            guard let match = active.rule.match(context) else { continue }
            var valid = match.consumedLines > 0 && match.consumedLines <= lines.count - index
            if case .custom(let kind, .block, _) = match.data {
                valid = valid && !kind.name.isEmpty && !NodeKind.builtins.contains(kind)
            } else { valid = false }
            if valid {
                for target in index..<(index + match.consumedLines) {
                    if context.line(at: target) == nil { valid = false; break }
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
            if valid { return match }
            builder.report(ParseDiagnostic(.invalidExtensionResult(active.rule.identifier), range: lines[index].range))
        }
        return nil
    }
}
