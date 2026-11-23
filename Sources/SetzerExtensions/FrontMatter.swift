public import SetzerSyntax
public import SetzerParser

/// Raw front matter from one document snapshot. No YAML/TOML deserialisation
/// or presentation policy is implied. Byte ranges retain the original source.
public struct FrontMatter: Hashable, Sendable {
    /// Delimiter family only; payloads remain raw, without YAML/TOML decoding.
    public enum Format: String, CaseIterable, Hashable, Sendable {
        case yaml, toml

        fileprivate var marker: UInt8 { self == .yaml ? 45 : 43 }
    }

    public static let identifier = "frontmatter"
    public static let kind = NodeKind("frontmatter.block")

    /// Select `frontmatter` in the profile and supply this implementation.
    /// Formats are independently disabled with `frontmatter.yaml` and
    /// `frontmatter.toml`.
    /// Strict CommonMark and GFM profiles are unchanged.
    public static let implementation = MarkdownExtension(identifier, nodeKinds: [kind], blockRules: [
        BlockRule("yaml", trigger: 45) { match($0, format: .yaml) },
        BlockRule("toml", trigger: 43) { match($0, format: .toml) },
    ])

    public let format: Format
    /// Includes both delimiters and the closing line ending, excluding a BOM.
    public let range: SourceRange
    /// Between the opening line ending and the beginning of the closing line.
    /// Empty metadata retains an empty insertion range.
    public let contentRange: SourceRange
    public let rawBytes: [UInt8]
    /// Replacement-decodes invalid UTF-8 only. Line endings and NUL are retained.
    public var rawText: String { String(decoding: rawBytes, as: UTF8.self) }

    /// Returns nil for a different node, invalid index or malformed custom
    /// payload. This value owns its bytes; offsets belong to the given snapshot.
    public init?(_ document: Document, at index: Int) {
        guard document.nodes.indices.contains(index) else { return nil }
        let node = document.nodes[index]
        guard case .custom(Self.kind, .block, let attributes) = node.data,
              node.firstChild == nil, case .string(let name) = attributes["format"],
              let format = Format(rawValue: name), node.sourceSegments.count == 1,
              let contentRange = node.sourceSegments.first else { return nil }
        self.format = format
        self.range = node.range
        self.contentRange = contentRange
        self.rawBytes = Array(document.source[contentRange.lowerBound..<contentRange.upperBound])
    }

    private static func match(_ context: BlockContext, format: Format) -> BlockMatch? {
        guard context.isDocumentStart else { return nil }
        let expectedStart = context.source.starts(with: [0xEF, 0xBB, 0xBF]) ? 3 : 0
        guard context.line.contentRange.lowerBound == expectedStart,
              let opening = fence(in: context.line, source: context.source, marker: format.marker) else { return nil }
        var next = context.lineIndex + 1
        while let line = context.line(at: next) {
            if let closing = fence(in: line, source: context.source, marker: format.marker) {
                let content = SourceRange(context.line.range.upperBound, line.range.lowerBound)
                return BlockMatch(consumedLines: next - context.lineIndex + 1,
                    data: .custom(kind: kind, role: .block, attributes: ["format": .string(format.rawValue)]),
                    sourceSegments: [content], tokens: [
                        BlockToken("frontmatter.fence.open", range: opening),
                        BlockToken("frontmatter.content", range: content),
                        BlockToken("frontmatter.fence.close", range: closing),
                    ])
            }
            next += 1
        }
        // A dangling opener does not swallow the remaining document.
        return nil
    }

    private static func fence(in line: SourceLine, source: [UInt8], marker: UInt8) -> SourceRange? {
        let range = line.contentRange
        guard line.virtualIndentation == 0, range.count >= 3,
              source[range.lowerBound] == marker,
              source[range.lowerBound + 1] == marker,
              source[range.lowerBound + 2] == marker,
              source[(range.lowerBound + 3)..<range.upperBound].allSatisfy({ $0 == 32 || $0 == 9 }) else { return nil }
        return SourceRange(range.lowerBound, range.lowerBound + 3)
    }
}
