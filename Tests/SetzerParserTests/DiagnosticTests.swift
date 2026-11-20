import GMSetzer
import Testing

struct DiagnosticTests {
    let message = DiagnosticMessage("test.fix", defaultText: "Example fix")

    @Test func fixesKeepOriginalBytesAndRejectStaleOrAmbiguousEdits() throws {
        let bytes = Array("😀 a\r\nb".utf8) + [0xFF]
        let fix = try SuggestedFix(message: message, edits: [
            SuggestedEdit(range: SourceRange(9, 10), expected: [0xFF], replacement: [0xFE]),
            SuggestedEdit(range: SourceRange(5, 6), expected: "a", replacement: "z"),
        ])
        #expect(try fix.applying(to: bytes) == Array("😀 z\r\nb".utf8) + [0xFE])
        #expect(throws: DiagnosticError.staleEdit) { try fix.applying(to: Array("😀 x\r\nb".utf8) + [0xFF]) }
        #expect(throws: DiagnosticError.invalidEdit) { try fix.applying(to: []) }
        #expect(throws: DiagnosticError.emptyFix) { try SuggestedFix(message: message, edits: []) }
        #expect(throws: DiagnosticError.invalidEdit) {
            try SuggestedFix(message: message, edits: [SuggestedEdit(range: SourceRange(0, 2), expected: "a", replacement: "")])
        }
        for ranges in [[SourceRange(0, 2), SourceRange(1, 3)], [SourceRange(1, 1), SourceRange(1, 1)],
                       [SourceRange(0, 1), SourceRange(1, 1)]] {
            #expect(throws: DiagnosticError.overlappingEdits) {
                try SuggestedFix(message: message, edits: ranges.map {
                    SuggestedEdit(range: $0, expected: [UInt8](repeating: 32, count: $0.count), replacement: [])
                })
            }
        }
    }

    @Test func reportsValidateAndOrderFindingsWithinTheirSnapshot() throws {
        let bytes = Array("abc".utf8)
        let first = try DocumentDiagnostic(provider: "test", code: "test.a", category: .style, severity: .warning,
                                          message: message, location: .source(SourceRange(0, 0)))
        let second = try DocumentDiagnostic(provider: "test", code: "test.b", category: .style, severity: .error,
                                           message: message, location: .source(SourceRange(0, 1)))
        let report = try DiagnosticReport(source: bytes, provider: "test", providerVersion: "1", dialect: "commonmark",
                                          configurationID: "rules-v1", findings: [first, second])
        #expect(report.findings == [second, first])
        #expect(report.source == bytes)
        #expect(throws: DiagnosticError.invalidIdentifier) {
            try DiagnosticReport(source: bytes, provider: "foreign", providerVersion: "1", dialect: "commonmark",
                                 configurationID: "rules-v1", findings: [first])
        }
    }

    @Test func locationsKeepZeroLengthRelatedAndPhysicalLineSemantics() throws {
        let source = Array("😀\r\nb\rc\n".utf8)
        let finding = try DocumentDiagnostic(provider: "test", code: "test.example", category: .style, severity: .warning,
            message: message, location: .source(SourceRange(4, 4)),
            related: [RelatedDiagnosticLocation(.line(start: 6)), RelatedDiagnosticLocation(.document)])
        try finding.validate(in: source)
        for start in [-1, 2, 5, 100] {
            let bad = try DocumentDiagnostic(provider: "test", code: "test.example", category: .style, severity: .warning,
                message: message, location: .line(start: start))
            #expect(throws: DiagnosticError.invalidLocation) { try bad.validate(in: source) }
        }
        for start in [0, 6, 8, 10] {
            let line = try DocumentDiagnostic(provider: "test", code: "test.example", category: .style, severity: .warning,
                message: message, location: .line(start: start))
            try line.validate(in: source)
        }
    }
}
