import GMSetzer
import Testing

struct NativeAnalysisTests {
    @Test func explicitRulesDeterministicConfigurationAndRelatedHeadings() throws {
        let document = MarkdownParser().parse("# A *one*\n\n### `B`\n\n# A one\n\ntext \t\n")
        #expect(try NativeAnalyzer.analyze(document, dialect: "commonmark").findings.isEmpty)
        let config = NativeAnalysisConfiguration(rules: Set(NativeRule.allCases))
        let report = try NativeAnalyzer.analyze(document, dialect: "commonmark", configuration: config)
        #expect(report.findings.map(\.code) == [NativeRule.headingLevel.rawValue, NativeRule.duplicateHeading.rawValue, NativeRule.trailingWhitespace.rawValue])
        #expect(report.findings[1].related.count == 1)
        #expect(report.configurationID == NativeAnalysisConfiguration(rules: [.trailingWhitespace, .duplicateHeading, .headingLevel]).identity)
        let fix = try #require(report.findings.last?.fixes.first)
        #expect(String(decoding: try fix.applying(to: document.source), as: UTF8.self).hasSuffix("text\n"))
    }

    @Test func scopesExcludeCodeHTMLAndUnknownExtensionsAndKeepHardBreaks() throws {
        let source = "# A `code`\n\n# A code\n\n```\n### ignored \t\n```\n\n<div>\n### ignored \t\n</div>\n\ntext  \nnext\n\nend \t"
        let document = MarkdownParser().parse(source)
        let config = NativeAnalysisConfiguration(rules: Set(NativeRule.allCases))
        let report = try NativeAnalyzer.analyze(document, dialect: "commonmark", configuration: config)
        #expect(report.findings.map(\.code) == [NativeRule.duplicateHeading.rawValue, NativeRule.trailingWhitespace.rawValue])
        let range = SourceRange(source.utf8.count - 2, source.utf8.count)
        let suppressed = NativeAnalysisConfiguration(rules: config.rules,
            suppressions: [NativeSuppression(rule: .trailingWhitespace, range: range)])
        #expect(try NativeAnalyzer.analyze(document, dialect: "commonmark", configuration: suppressed).findings.count == 1)
        let otherRule = NativeAnalysisConfiguration(rules: config.rules,
            suppressions: [NativeSuppression(rule: .headingLevel, range: document.root.range)])
        #expect(try NativeAnalyzer.analyze(document, dialect: "commonmark", configuration: otherRule).findings == report.findings)
        let bytes = Array("# X\n".utf8)
        var builder = DocumentBuilder(source: bytes)
        let custom = try builder.append(.custom(kind: NodeKind("test.box"), role: .block, attributes: [:]), range: SourceRange(0, bytes.count))
        try builder.append(.heading(level: 3), range: SourceRange(0, bytes.count), to: custom)
        #expect(try NativeAnalyzer.analyze(builder.build(), dialect: "commonmark", configuration: config).findings.isEmpty)
    }

    @Test func emptyListMarkerWhitespaceNeverBecomesADestructiveFix() throws {
        let document = MarkdownParser().parse("1. \t\n\n- \t\n")
        #expect(try NativeAnalyzer.analyze(document, dialect: "commonmark", configuration:
            NativeAnalysisConfiguration(rules: [.trailingWhitespace])).findings.isEmpty)
    }

    @Test func invalidConfigurationIsNotADocumentFinding() throws {
        let document = MarkdownParser().parse("😀\r\n")
        for range in [SourceRange(1, 2), SourceRange(4, 5), SourceRange(0, 100)] {
            #expect(throws: NativeAnalysisError.invalidSuppression) {
                try NativeAnalyzer.analyze(document, dialect: "commonmark", configuration:
                    NativeAnalysisConfiguration(rules: [.headingLevel], suppressions: [.init(rule: .headingLevel, range: range)]))
            }
        }
        #expect(throws: NativeAnalysisError.invalidDialect) { try NativeAnalyzer.analyze(document, dialect: "") }
    }
}
