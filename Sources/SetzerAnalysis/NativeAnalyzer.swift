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

public enum NativeAnalysisError: Error, Equatable, Sendable { case invalidSuppression }

/// Pure analysis of an existing parse; no parser, UI, files or renderer.
public enum NativeAnalyzer {
    public static let provider = "gmsetzer.native"
    public static let version = GMSetzerVersion.current

    public static func analyze(_ document: Document, dialect: MarkdownDialect = .commonMark,
                               configuration: NativeAnalysisConfiguration = .init()) throws -> DiagnosticReport {
        if configuration.rules.isEmpty && configuration.suppressions.isEmpty {
            return try DiagnosticReport(source: document.source, provider: provider, providerVersion: version,
                dialect: dialect.identifier, configurationID: configuration.identity, findings: [])
        }
        for scope in configuration.suppressions {
            guard SourceIndex.isBoundary(scope.range.lowerBound, in: document.source),
                  SourceIndex.isBoundary(scope.range.upperBound, in: document.source) else {
                throw NativeAnalysisError.invalidSuppression
            }
        }
        var suppressions: [NativeRule: SuppressionCursor] = [:]
        for scope in configuration.suppressions.sorted(by: {
            $0.range.lowerBound == $1.range.lowerBound ? $0.range.upperBound < $1.range.upperBound
                : $0.range.lowerBound < $1.range.lowerBound
        }) {
            suppressions[scope.rule, default: SuppressionCursor()].ranges.append(scope.range)
        }
        var findings: [DocumentDiagnostic] = []
        func emit(_ rule: NativeRule, range: SourceRange, text: String,
                  related: [RelatedDiagnosticLocation] = [], fixes: [SuggestedFix] = []) throws {
            if suppressions[rule]?.suppresses(range) == true { return }
            findings.append(try DocumentDiagnostic(provider: provider, code: rule.rawValue,
                category: .style, severity: .warning,
                message: DiagnosticMessage(rule.rawValue, defaultText: text), location: .source(range),
                related: related, fixes: fixes))
        }
        if !configuration.rules.isEmpty {
            var excluded: [SourceRange] = [], hardBreaks: [SourceRange] = [], prose: [SourceRange] = []
            if configuration.rules.contains(.trailingWhitespace) {
                // Preorder is already source ordered. Merge nested/overlapping
                // protected ranges while walking once; no scope sorts needed.
                for index in DocumentTraversal(document, includeCustomContent: false) {
                    let node = document.nodes[index]
                    switch node.data {
                    case .codeBlock, .code, .htmlBlock, .htmlInline, .referenceDefinition, .custom:
                        if let last = excluded.last, node.range.lowerBound <= last.upperBound {
                            excluded[excluded.count - 1] = SourceRange(last.lowerBound, max(last.upperBound, node.range.upperBound))
                        } else { excluded.append(node.range) }
                    case .hardBreak: hardBreaks.append(node.range)
                    case .paragraph, .heading: prose.append(node.range)
                    default: break
                    }
                }
            }
            var excludedCursor = 0, breakCursor = 0, proseCursor = 0
            var previousLevel = 0
            var seen: [[UInt8]: SourceRange] = [:]
            if configuration.rules.contains(.headingLevel) || configuration.rules.contains(.duplicateHeading) {
                for index in DocumentTraversal(document, blocksOnly: true, includeCustomContent: false) {
                    guard case .heading(let level) = document.nodes[index].data else { continue }
                    let range = document.nodes[index].range
                    if configuration.rules.contains(.headingLevel), level > previousLevel + 1 {
                        try emit(.headingLevel, range: range, text: "Heading skips a level (expected at most \(previousLevel + 1)).")
                    }
                    previousLevel = level
                    // Case-sensitive decoded text, whitespace collapsed, byte-exact
                    // Unicode identity. No canonical/case-fold compatibility claim.
                    if configuration.rules.contains(.duplicateHeading) {
                        let key = Array(document.plainText(of: index).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").utf8)
                        guard !key.isEmpty else { continue }
                        if let first = seen[key] {
                            try emit(.duplicateHeading, range: range, text: "Heading repeats an earlier heading.",
                                     related: [RelatedDiagnosticLocation(.source(first))])
                        } else { seen[key] = range }
                    }
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
                                    dialect: dialect.identifier, configurationID: configuration.identity, findings: findings)
    }
}

/// Findings for each rule are emitted in source order. Prefix-maximum end
/// preserves containment semantics even for nested suppression ranges; scopes
/// are never unioned (which could suppress a finding crossing two scopes).
private struct SuppressionCursor {
    var ranges: [SourceRange] = []
    var next = 0
    var maximumEnd = -1
    mutating func suppresses(_ range: SourceRange) -> Bool {
        while next < ranges.count, ranges[next].lowerBound <= range.lowerBound {
            maximumEnd = max(maximumEnd, ranges[next].upperBound); next += 1
        }
        return maximumEnd >= range.upperBound
    }
}
