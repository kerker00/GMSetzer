public import SetzerSyntax

/// Optional text lookup for native findings and fix titles. The caller chooses
/// a language; analysis never reads a process locale or changes its result.
public enum NativeAnalysisMessages {
    /// Supports English and German BCP 47 primary language subtags, including
    /// regional tags such as `en-GB` and `de-DE`, case-insensitively. Unknown
    /// languages/keys and missing or invalid arguments retain `defaultText`.
    /// Extra arguments are ignored so consumers can extend their own catalogues.
    public static func text(for message: DiagnosticMessage, languageTag: String) -> String {
        let primary = languageTag.split(separator: "-", maxSplits: 1,
            omittingEmptySubsequences: false).first?.lowercased()
        guard primary == "en" || primary == "de" else { return message.defaultText }
        let german = primary == "de"
        switch message.key {
        case NativeRule.headingLevel.rawValue:
            guard case .integer(let maximumLevel) = message.arguments["maximumLevel"],
                  (1...6).contains(maximumLevel) else { return message.defaultText }
            return headingLevelText(maximumLevel, german: german)
        case NativeRule.duplicateHeading.rawValue:
            return german ? "Überschrift wiederholt eine frühere Überschrift." : duplicateHeading.defaultText
        case NativeRule.trailingWhitespace.rawValue:
            return german ? "Leerraum am Zeilenende hat keine Markdown-Bedeutung." : trailingWhitespace.defaultText
        case removeTrailingWhitespace.key:
            return german ? "Leerraum am Zeilenende entfernen." : removeTrailingWhitespace.defaultText
        default:
            return message.defaultText
        }
    }

    static func headingLevel(maximumLevel: Int) -> DiagnosticMessage {
        DiagnosticMessage(NativeRule.headingLevel.rawValue,
            arguments: ["maximumLevel": .integer(maximumLevel)],
            defaultText: headingLevelText(maximumLevel, german: false))
    }

    static let duplicateHeading = DiagnosticMessage(NativeRule.duplicateHeading.rawValue,
        defaultText: "Heading repeats an earlier heading.")
    static let trailingWhitespace = DiagnosticMessage(NativeRule.trailingWhitespace.rawValue,
        defaultText: "Trailing whitespace has no Markdown meaning.")
    static let removeTrailingWhitespace = DiagnosticMessage("gmsetzer.remove-trailing-whitespace",
        defaultText: "Remove trailing whitespace.")

    private static func headingLevelText(_ maximumLevel: Int, german: Bool) -> String {
        german
            ? "Überschrift überspringt eine Ebene (höchstens Ebene \(maximumLevel) erwartet)."
            : "Heading skips a level (expected at most \(maximumLevel))."
    }
}
