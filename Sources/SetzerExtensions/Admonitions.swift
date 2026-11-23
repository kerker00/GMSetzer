public import SetzerSyntax
public import SetzerParser

/// GitHub-style marker-only alert headers. Body Markdown stays in the tree.
public struct Alert: Hashable, Sendable {
    /// The five recognised marker spellings; values retain uppercase source names.
    public enum Category: String, CaseIterable, Hashable, Sendable {
        case note = "NOTE", tip = "TIP", important = "IMPORTANT", warning = "WARNING", caution = "CAUTION"
        public var defaultTitle: String { rawValue.prefix(1) + rawValue.dropFirst().lowercased() }
    }
    public static let identifier = "alerts"
    public static let kind = NodeKind("alerts.block")
    public static let implementation = MarkdownExtension(identifier,
        nodeKinds: [kind, AdmonitionTransform.headerKind(callouts: false)], blockRules: [
            BlockRule("recognise", trigger: 91) { AdmonitionTransform.matchHeader($0, callouts: false) },
        ], transforms: [BlockTransform("wrap") { try AdmonitionTransform.apply($0, callouts: false) }])
    public let category: Category
    public let range: SourceRange

    /// Reads a valid alert view; invalid indices and other/custom malformed
    /// node kinds return nil rather than being interpreted as an alert.
    public init?(_ document: Document, at index: Int) {
        guard document.nodes.indices.contains(index) else { return nil }
        let node = document.nodes[index]
        guard case .custom(Self.kind, .block, let attributes) = node.data,
              case .string(let raw) = attributes["type"], let category = Category(rawValue: raw) else { return nil }
        self.category = category; self.range = node.range
    }
}

/// Obsidian-style named callouts, with optional parsed titles and folding.
public struct Callout: Hashable, Sendable {
    /// Static aside, initially expanded details or initially collapsed details.
    public enum Fold: String, Hashable, Sendable { case none, expanded, collapsed }
    public static let identifier = "callouts"
    public static let kind = NodeKind("callouts.block")
    public static let titleKind = NodeKind("callouts.title")
    public static let implementation = MarkdownExtension(identifier,
        nodeKinds: [kind, titleKind, AdmonitionTransform.headerKind(callouts: true)], blockRules: [
            BlockRule("recognise", trigger: 91) { AdmonitionTransform.matchHeader($0, callouts: true) },
        ], transforms: [BlockTransform("wrap") { try AdmonitionTransform.apply($0, callouts: true) }])
    public let type: String
    /// Built-in style after alias lookup; unknown names use `note`.
    public let style: String
    public let fold: Fold
    /// Raw Markdown for a custom title, otherwise the generated type title.
    public let title: String
    public let hasCustomTitle: Bool
    /// Custom title container in this snapshot, or nil for a generated title.
    public let titleNode: Int?
    public let range: SourceRange

    /// Reads a well-formed callout and optional parsed title from this snapshot.
    /// Invalid indices, types, fold values or title topology return nil.
    public init?(_ document: Document, at index: Int) {
        guard document.nodes.indices.contains(index) else { return nil }
        let node = document.nodes[index]
        guard case .custom(Self.kind, .block, let attributes) = node.data,
              case .string(let type) = attributes["type"], Self.validType(type), type == type.lowercased(),
              case .string(let rawFold) = attributes["fold"], let fold = Fold(rawValue: rawFold) else { return nil }
        let title: String
        let titleNode: Int?
        if let custom = attributes["title"] {
            guard case .string(let text) = custom, let first = node.firstChild,
                  case .custom(Self.titleKind, .block, _) = document.nodes[first].data,
                  let paragraph = document.nodes[first].firstChild,
                  document.nodes[paragraph].kind == .paragraph,
                  document.nodes[paragraph].nextSibling == nil else { return nil }
            title = text; titleNode = first
        } else {
            title = type.split(whereSeparator: { $0 == "-" || $0 == "_" }).map {
                $0.prefix(1).uppercased() + $0.dropFirst()
            }.joined(separator: " ")
            titleNode = nil
        }
        self.type = type; self.style = Self.styles[type] ?? "note"; self.fold = fold
        self.title = title; self.titleNode = titleNode; self.hasCustomTitle = titleNode != nil
        self.range = node.range
    }

    fileprivate static func validType(_ value: String) -> Bool {
        value.utf8.contains { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) }
        && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }
    private static let styles: [String: String] = {
        let groups = ["note": [], "abstract": ["summary", "tldr"], "info": [], "todo": [],
            "tip": ["hint", "important"], "success": ["check", "done"], "question": ["help", "faq"],
            "warning": ["caution", "attention"], "failure": ["fail", "missing"], "danger": ["error"],
            "bug": [], "example": [], "quote": ["cite"]]
        var result: [String: String] = [:]
        for (name, aliases) in groups {
            result[name] = name
            for alias in aliases { result[alias] = name }
        }
        return result
    }()
}

private enum AdmonitionTransform {
    static func headerKind(callouts: Bool) -> NodeKind {
        NodeKind(callouts ? "callouts.header" : "alerts.header")
    }

    static func matchHeader(_ context: BlockContext, callouts: Bool) -> BlockMatch? {
        guard context.isBlockQuoteStart else { return nil }
        let source = context.source
        var line: SourceRange?
        for columns in 0...3 {
            if let view = context.droppingIndentation(columns, from: context.line),
               view.virtualIndentation == 0, view.contentRange.count >= 4,
               source[view.contentRange.lowerBound] == 91 {
                line = view.contentRange; break
            }
        }
        guard let line else { return nil }
        let start = line.lowerBound
        guard source[start + 1] == 33 else { return nil }
        var cursor = start + 2
        while cursor < line.upperBound && source[cursor] != 93 {
            let byte = source[cursor]
            guard (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 45 || byte == 95 else { return nil }
            cursor += 1
        }
        guard cursor > start + 2, cursor < line.upperBound else { return nil }
        let name = SourceRange(start + 2, cursor)
        let rawType = String(decoding: source[name.lowerBound..<name.upperBound], as: UTF8.self)
        guard Callout.validType(rawType) else { return nil }
        let close = SourceRange(cursor, cursor + 1)
        cursor += 1
        var fold = Callout.Fold.none
        var foldRange: SourceRange?
        if callouts, cursor < line.upperBound, source[cursor] == 43 || source[cursor] == 45 {
            fold = source[cursor] == 43 ? .expanded : .collapsed
            foldRange = SourceRange(cursor, cursor + 1); cursor += 1
        }
        guard cursor == line.upperBound || source[cursor] == 32 || source[cursor] == 9 else { return nil }
        while cursor < line.upperBound && (source[cursor] == 32 || source[cursor] == 9) { cursor += 1 }
        var end = line.upperBound
        while end > cursor && (source[end - 1] == 32 || source[end - 1] == 9) { end -= 1 }
        let title = cursor < end ? SourceRange(cursor, end) : nil
        if !callouts, Alert.Category(rawValue: rawType) == nil || title != nil { return nil }
        var attributes: [String: SyntaxValue] = ["type": .string(callouts ? rawType.lowercased() : rawType)]
        if callouts { attributes["fold"] = .string(fold.rawValue) }
        if let title { attributes["title"] = .string(repaired(source[title.lowerBound..<title.upperBound])) }
        let owner = callouts ? Callout.identifier : Alert.identifier
        var tokens = [BlockToken(owner + ".marker.open", range: SourceRange(start, start + 2)),
            BlockToken(owner + ".type", range: name), BlockToken(owner + ".marker.close", range: close)]
        if let range = foldRange { tokens.append(BlockToken(owner + ".fold", range: range)) }
        if let range = title { tokens.append(BlockToken(owner + ".title", range: range)) }
        return BlockMatch(consumedLines: 1,
            data: .custom(kind: headerKind(callouts: callouts), role: .block, attributes: attributes),
            sourceSegments: title.map { [$0] } ?? [], tokens: tokens)
    }

    static func apply(_ document: Document, callouts: Bool) throws -> Document {
        let kind = callouts ? Callout.kind : Alert.kind
        let headerKind = headerKind(callouts: callouts)
        var headers: [Int: Int] = [:]
        for (index, node) in document.nodes.enumerated() where node.kind == .blockQuote {
            if let first = node.firstChild, document.nodes[first].kind == headerKind { headers[index] = first }
        }
        guard !headers.isEmpty else { return document }
        var builder = DocumentBuilder(source: document.source, collectSyntaxDetails: document.tokens != nil)
        builder.renderingPolicy = document.renderingPolicy
        builder.reserveCapacity(document.nodes.count + headers.count * 2)
        for diagnostic in document.diagnostics { builder.report(diagnostic) }
        var mapped = [Int](repeating: -1, count: document.nodes.count); mapped[0] = 0
        var pending = document.children(of: 0).reversed().map { ($0, 0) }
        while let (old, parent) = pending.popLast() {
            let node = document.nodes[old]
            guard let headerIndex = headers[old],
                  case .custom(_, .block, let attributes) = document.nodes[headerIndex].data else {
                let index = try builder.append(node.data, range: node.range, sourceSegments: node.sourceSegments,
                    fallbackLiteral: document.customLeafFallbacks[old], to: parent)
                mapped[old] = index
                for child in document.children(of: old).reversed() { pending.append((child, index)) }
                continue
            }
            let title = document.nodes[headerIndex].sourceSegments.first
            let body = Array(document.children(of: old).dropFirst())
            let empty = title == nil && body.isEmpty
            let index = try builder.append(.custom(kind: kind, role: .block, attributes: attributes), range: node.range,
                sourceSegments: node.sourceSegments, fallbackLiteral: empty ? "" : nil, to: parent)
            mapped[old] = index; mapped[headerIndex] = index
            if let title {
                let container = try builder.append(.custom(kind: Callout.titleKind, role: .block, attributes: [:]), range: title, to: index)
                let paragraph = try builder.append(.paragraph, range: title, sourceSegments: [title], to: container)
                try builder.append(.text(repaired(document.source[title.lowerBound..<title.upperBound])), range: title,
                    sourceSegments: [title], to: paragraph)
            }
            for child in body.reversed() { pending.append((child, index)) }
        }
        for token in document.tokens ?? [] {
            let owner = mapped[token.owner]
            if owner >= 0 { builder.record(SyntaxToken(token.role, range: token.range, owner: owner)) }
        }
        return try builder.build()
    }

    private static func repaired(_ source: ArraySlice<UInt8>) -> String {
        var bytes: [UInt8] = []
        for byte in source {
            if byte == 0 { bytes.append(contentsOf: [0xEF, 0xBF, 0xBD]) } else { bytes.append(byte) }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
