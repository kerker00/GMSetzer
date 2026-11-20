import GMSetzer
import Testing

struct NativeAnalysisMessagesTests {
    @Test func nativeFindingsAndFixTitlesHaveEnglishAndGermanText() throws {
        let source = "# Anfang\n\n### Ende\n\n# Anfang\n\nText \t\n"
        let document = MarkdownParser().parse(source)
        let report = try NativeAnalyzer.analyze(document,
            configuration: NativeAnalysisConfiguration(rules: Set(NativeRule.allCases)))
        #expect(report.findings.map(\.message.key) == [
            "gmsetzer.heading-level", "gmsetzer.duplicate-heading", "gmsetzer.trailing-whitespace",
        ])
        #expect(report.findings.map { NativeAnalysisMessages.text(for: $0.message, languageTag: "de") } == [
            "Überschrift überspringt eine Ebene (höchstens Ebene 2 erwartet).",
            "Überschrift wiederholt eine frühere Überschrift.",
            "Leerraum am Zeilenende hat keine Markdown-Bedeutung.",
        ])
        #expect(report.findings.map(\.message.defaultText) == [
            "Heading skips a level (expected at most 2).",
            "Heading repeats an earlier heading.",
            "Trailing whitespace has no Markdown meaning.",
        ])
        for finding in report.findings {
            #expect(NativeAnalysisMessages.text(for: finding.message, languageTag: "en") == finding.message.defaultText)
        }
        let fix = try #require(report.findings.last?.fixes.first)
        #expect(fix.message.key == "gmsetzer.remove-trailing-whitespace")
        #expect(fix.message.arguments.isEmpty)
        #expect(fix.message.defaultText == "Remove trailing whitespace.")
        #expect(NativeAnalysisMessages.text(for: fix.message, languageTag: "de") == "Leerraum am Zeilenende entfernen.")
        #expect(NativeAnalysisMessages.text(for: fix.message, languageTag: "en") == "Remove trailing whitespace.")
        #expect(String(decoding: try fix.applying(to: document.source), as: UTF8.self)
            == "# Anfang\n\n### Ende\n\n# Anfang\n\nText\n")
    }

    @Test func headingArgumentsDescribeTheActualPermittedLevel() throws {
        let document = MarkdownParser().parse("### Erster\n\n# H1\n\n#### H4\n\n###### H6\n")
        let report = try NativeAnalyzer.analyze(document,
            configuration: NativeAnalysisConfiguration(rules: [.headingLevel]))
        #expect(report.findings.map(\.message.arguments) == [
            ["maximumLevel": .integer(1)], ["maximumLevel": .integer(2)], ["maximumLevel": .integer(5)],
        ])
        #expect(report.findings.map { NativeAnalysisMessages.text(for: $0.message, languageTag: "de-DE") } == [
            "Überschrift überspringt eine Ebene (höchstens Ebene 1 erwartet).",
            "Überschrift überspringt eine Ebene (höchstens Ebene 2 erwartet).",
            "Überschrift überspringt eine Ebene (höchstens Ebene 5 erwartet).",
        ])
    }

    @Test func languageSelectionIsExplicitAndUnsupportedLanguagesKeepTheFallback() {
        let message = DiagnosticMessage("gmsetzer.duplicate-heading", defaultText: "Custom fallback 🐱")
        for language in ["de", "de-DE", "de-AT", "DE-ch"] {
            #expect(NativeAnalysisMessages.text(for: message, languageTag: language)
                == "Überschrift wiederholt eine frühere Überschrift.")
        }
        for language in ["en", "en-US", "EN-gb"] {
            #expect(NativeAnalysisMessages.text(for: message, languageTag: language)
                == "Heading repeats an earlier heading.")
        }
        for language in ["", "fr", "ja-JP", "de_DE", "-de", " de "] {
            #expect(NativeAnalysisMessages.text(for: message, languageTag: language) == message.defaultText)
        }
    }

    @Test func unknownKeysAndInvalidHeadingArgumentsNeverInventText() {
        let unknown = DiagnosticMessage("consumer.custom", arguments: ["title": .string("Titel")],
            defaultText: "Keep the producer's text.")
        for language in ["de", "en"] {
            #expect(NativeAnalysisMessages.text(for: unknown, languageTag: language) == unknown.defaultText)
            for arguments: [String: SyntaxValue] in [
                [:], ["maximumLevel": .string("2")], ["maximumLevel": .boolean(true)],
                ["maximumLevel": .integer(0)], ["maximumLevel": .integer(7)],
            ] {
                // Empty arguments also cover reports produced by v0.4.0.
                let message = DiagnosticMessage("gmsetzer.heading-level", arguments: arguments,
                    defaultText: "Original heading text.")
                #expect(NativeAnalysisMessages.text(for: message, languageTag: language) == message.defaultText)
            }
        }
    }

    @Test func validHeadingArgumentsAllowAdditionalConsumerMetadata() {
        let message = DiagnosticMessage("gmsetzer.heading-level",
            arguments: ["maximumLevel": .integer(6), "consumer.extra": .string("ignored")],
            defaultText: "Fallback")
        #expect(NativeAnalysisMessages.text(for: message, languageTag: "de")
            == "Überschrift überspringt eine Ebene (höchstens Ebene 6 erwartet).")
        #expect(NativeAnalysisMessages.text(for: message, languageTag: "en")
            == "Heading skips a level (expected at most 6).")
    }
}
