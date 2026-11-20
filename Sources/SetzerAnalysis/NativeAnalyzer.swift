public import SetzerSyntax

public enum NativeRule: String, CaseIterable, Hashable, Sendable {
    case headingLevel = "gmsetzer.heading-level"
    case duplicateHeading = "gmsetzer.duplicate-heading"
    case trailingWhitespace = "gmsetzer.trailing-whitespace"
}

/// Explicit source scopes, resolved by the caller. No comment directive or
/// markdownlint suppression language is interpreted by this native provider.
public struct NativeSuppression: Hashable, Sendable {
    public let rule: NativeRule
    public let range: SourceRange
    public init(rule: NativeRule, range: SourceRange) { self.rule = rule; self.range = range }
}

public struct NativeAnalysisConfiguration: Hashable, Sendable {
    /// Empty by default: analysis is independent of parsing and highlighting.
    public var rules: Set<NativeRule>
    public var suppressions: [NativeSuppression]
    public init(rules: Set<NativeRule> = [], suppressions: [NativeSuppression] = []) {
        self.rules = rules; self.suppressions = suppressions
    }
    /// Stable, lossless identity, independent of Set order and process hashing.
    public var identity: String {
        let scopes = Set(suppressions).map { "\($0.rule.rawValue):\($0.range.lowerBound):\($0.range.upperBound)" }.sorted()
        return "native-v1|" + rules.map(\.rawValue).sorted().joined(separator: ",") + "|" + scopes.joined(separator: ",")
    }
}

public enum NativeAnalysisError: Error, Equatable, Sendable { case invalidSuppression, invalidDialect }

/// Pure analysis of an existing parse; no parser, UI, files or renderer.
public enum NativeAnalyzer {
    public static let provider = "gmsetzer.native"
    public static let version = "0.1.0-m3"

    public static func analyze(_ document: Document, dialect: String,
                               configuration: NativeAnalysisConfiguration = .init()) throws -> DiagnosticReport {
        guard !dialect.isEmpty else { throw NativeAnalysisError.invalidDialect }
        if configuration.rules.isEmpty && configuration.suppressions.isEmpty {
            return try DiagnosticReport(source: document.source, provider: provider, providerVersion: version,
                dialect: dialect, configurationID: configuration.identity, findings: [])
        }
        let positions = SourceIndex(document.source)
        for scope in configuration.suppressions {
            guard positions.utf16Range(for: scope.range) != nil else { throw NativeAnalysisError.invalidSuppression }
        }
        var findings: [DocumentDiagnostic] = []
        func emit(_ rule: NativeRule, range: SourceRange, text: String,
                  related: [RelatedDiagnosticLocation] = [], fixes: [SuggestedFix] = []) throws {
            guard !configuration.suppressions.contains(where: { $0.rule == rule && $0.range.contains(range) }) else { return }
            findings.append(try DocumentDiagnostic(provider: provider, code: rule.rawValue,
                category: .style, severity: .warning,
                message: DiagnosticMessage(rule.rawValue, defaultText: text), location: .source(range),
                related: related, fixes: fixes))
        }
        if !configuration.rules.isEmpty {
            let tree = DocumentIndex(document)
            let excluded = document.nodes.compactMap { node -> SourceRange? in
                switch node.data {
                case .codeBlock, .code, .htmlBlock, .htmlInline, .referenceDefinition, .custom: node.range
                default: nil
                }
            }.sorted { $0.lowerBound < $1.lowerBound }
            let hardBreaks = document.nodes.compactMap { node -> SourceRange? in
                if case .hardBreak = node.data { return node.range }; return nil
            }.sorted { $0.lowerBound < $1.lowerBound }
            let prose = document.nodes.compactMap { node -> SourceRange? in
                switch node.data { case .paragraph, .heading: node.range; default: nil }
            }.sorted { $0.lowerBound < $1.lowerBound }
            var excludedCursor = 0, breakCursor = 0, proseCursor = 0
            var previousLevel = 0
            var seen: [[UInt8]: SourceRange] = [:]
            for entry in tree.outline() {
                guard !tree.ancestors(of: entry.node).contains(where: {
                    if case .custom = document.nodes[$0].data { return true }; return false
                }) else { continue }
                if configuration.rules.contains(.headingLevel), entry.level > previousLevel + 1 {
                    try emit(.headingLevel, range: entry.range, text: "Heading skips a level (expected at most \(previousLevel + 1)).")
                }
                previousLevel = entry.level
                // Case-sensitive decoded text, whitespace collapsed, byte-exact
                // Unicode identity. No canonical/case-fold compatibility claim.
                let key = Array(entry.title.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").utf8)
                if configuration.rules.contains(.duplicateHeading), !key.isEmpty {
                    if let first = seen[key] {
                        try emit(.duplicateHeading, range: entry.range, text: "Heading repeats an earlier heading.",
                                 related: [RelatedDiagnosticLocation(.source(first))])
                    } else { seen[key] = entry.range }
                }
            }
            if configuration.rules.contains(.trailingWhitespace) {
                var start = 0
                while start < document.source.count {
                    var end = start
                    while end < document.source.count, document.source[end] != 10, document.source[end] != 13 { end += 1 }
                    var trim = end
                    while trim > start, document.source[trim - 1] == 32 || document.source[trim - 1] == 9 { trim -= 1 }
                    if trim < end {
                        let range = SourceRange(trim, end)
                        while excludedCursor < excluded.count, excluded[excludedCursor].upperBound <= trim { excludedCursor += 1 }
                        while breakCursor < hardBreaks.count, hardBreaks[breakCursor].upperBound <= trim { breakCursor += 1 }
                        let hardBreak = breakCursor < hardBreaks.count && hardBreaks[breakCursor].lowerBound < end
                        let protected = excludedCursor < excluded.count && excluded[excludedCursor].lowerBound < end
                        while proseCursor < prose.count, prose[proseCursor].upperBound < end { proseCursor += 1 }
                        // Restrict fixes to prose/heading trivia. In particular,
                        // whitespace after an empty list marker can be syntax.
                        let inProse = proseCursor < prose.count && prose[proseCursor].lowerBound < trim && end <= prose[proseCursor].upperBound
                        if inProse && !hardBreak && !protected {
                            let fix = try SuggestedFix(message: DiagnosticMessage("gmsetzer.remove-trailing-whitespace", defaultText: "Remove trailing whitespace."),
                                edits: [SuggestedEdit(range: range, expected: Array(document.source[trim..<end]), replacement: [])])
                            try emit(.trailingWhitespace, range: range, text: "Trailing whitespace has no Markdown meaning.", fixes: [fix])
                        }
                    }
                    if end < document.source.count, document.source[end] == 13,
                       end + 1 < document.source.count, document.source[end + 1] == 10 { end += 1 }
                    start = end + 1
                }
            }
        }
        return try DiagnosticReport(source: document.source, provider: provider, providerVersion: version,
                                    dialect: dialect, configurationID: configuration.identity, findings: findings)
    }
}
