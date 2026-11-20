/// Presentation-free document findings. Parser configuration/runtime failures
/// remain separate (`ConfigurationIssue`/`ParseDiagnostic`); legal Markdown
/// fallbacks do not automatically produce a finding.
public enum DiagnosticSeverity: Int, Hashable, Sendable {
    case information, warning, error
}

public enum DiagnosticCategory: String, Hashable, Sendable {
    case syntax, style, accessibility
}

public enum DiagnosticLocation: Hashable, Sendable {
    /// Empty ranges are insertion/caret locations; never widen to nearby text.
    case source(SourceRange)
    /// Original byte offset of the first byte of a physical line (including EOF).
    case line(start: Int)
    case document

    fileprivate func validate(in source: [UInt8]) throws {
        switch self {
        case .source(let range):
            guard range.upperBound <= source.count else { throw DiagnosticError.invalidLocation }
        case .line(let start):
            guard start >= 0, start <= source.count else { throw DiagnosticError.invalidLocation }
            if start > 0 {
                let previous = source[start - 1]
                guard previous == 10 || (previous == 13 && (start == source.count || source[start] != 10)) else {
                    throw DiagnosticError.invalidLocation
                }
            }
        case .document: break
        }
    }
}

public struct DiagnosticMessage: Hashable, Sendable {
    public let key: String
    public let arguments: [String: SyntaxValue]
    public let defaultText: String

    public init(_ key: String, arguments: [String: SyntaxValue] = [:], defaultText: String) {
        self.key = key
        self.arguments = arguments
        self.defaultText = defaultText
    }
}

public struct RelatedDiagnosticLocation: Hashable, Sendable {
    public let location: DiagnosticLocation
    public let message: DiagnosticMessage?

    public init(_ location: DiagnosticLocation, message: DiagnosticMessage? = nil) {
        self.location = location
        self.message = message
    }
}

/// Original-byte preconditions preserve malformed UTF-8 as well as normal text.
/// These values are advisory; the editor validates its full result stamp and
/// applies a chosen fix through its normal undo/IME-safe transaction path.
public struct SuggestedEdit: Hashable, Sendable {
    public let range: SourceRange
    public let expected: [UInt8]
    public let replacement: [UInt8]

    public init(range: SourceRange, expected: [UInt8], replacement: [UInt8]) {
        self.range = range
        self.expected = expected
        self.replacement = replacement
    }

    public init(range: SourceRange, expected: String, replacement: String) {
        self.init(range: range, expected: Array(expected.utf8), replacement: Array(replacement.utf8))
    }
}

public enum DiagnosticError: Error, Hashable, Sendable {
    case invalidIdentifier
    case invalidLocation
    case emptyFix
    case invalidEdit
    case overlappingEdits
    case staleEdit
}

public struct SuggestedFix: Hashable, Sendable {
    public let message: DiagnosticMessage
    /// Canonical source order. Adjacent nonempty replacements are allowed;
    /// insertions sharing a replacement boundary are ambiguous and rejected.
    public let edits: [SuggestedEdit]

    public init(message: DiagnosticMessage, edits: [SuggestedEdit]) throws {
        guard !edits.isEmpty else { throw DiagnosticError.emptyFix }
        let ordered = edits.sorted {
            $0.range.lowerBound == $1.range.lowerBound ? $0.range.upperBound < $1.range.upperBound
                : $0.range.lowerBound < $1.range.lowerBound
        }
        for (index, edit) in ordered.enumerated() {
            guard edit.expected.count == edit.range.count else { throw DiagnosticError.invalidEdit }
            if index > 0 {
                let previous = ordered[index - 1].range
                if previous.upperBound > edit.range.lowerBound ||
                    (previous.upperBound == edit.range.lowerBound && (previous.isEmpty || edit.range.isEmpty)) {
                    throw DiagnosticError.overlappingEdits
                }
            }
        }
        self.message = message
        self.edits = ordered
    }

    public func validate(in source: [UInt8]) throws {
        for edit in edits {
            guard edit.range.upperBound <= source.count else { throw DiagnosticError.invalidEdit }
            guard source[edit.range.lowerBound..<edit.range.upperBound].elementsEqual(edit.expected) else {
                throw DiagnosticError.staleEdit
            }
        }
    }

    /// Pure snapshot transformation for adapters/tests. Does not write a file,
    /// mutate a document or grant permission to apply a fix automatically.
    public func applying(to source: [UInt8]) throws -> [UInt8] {
        try validate(in: source)
        var output: [UInt8] = []
        var cursor = 0
        for edit in edits {
            output.append(contentsOf: source[cursor..<edit.range.lowerBound])
            output.append(contentsOf: edit.replacement)
            cursor = edit.range.upperBound
        }
        output.append(contentsOf: source[cursor...])
        return output
    }
}

public struct DocumentDiagnostic: Hashable, Sendable {
    public let provider: String
    public let code: String
    public let category: DiagnosticCategory
    public let severity: DiagnosticSeverity
    public let message: DiagnosticMessage
    public let location: DiagnosticLocation
    public let related: [RelatedDiagnosticLocation]
    public let fixes: [SuggestedFix]

    public init(provider: String, code: String, category: DiagnosticCategory, severity: DiagnosticSeverity,
                message: DiagnosticMessage, location: DiagnosticLocation,
                related: [RelatedDiagnosticLocation] = [], fixes: [SuggestedFix] = []) throws {
        guard !provider.isEmpty, !code.isEmpty, !message.key.isEmpty else { throw DiagnosticError.invalidIdentifier }
        self.provider = provider
        self.code = code
        self.category = category
        self.severity = severity
        self.message = message
        self.location = location
        self.related = related
        self.fixes = fixes
    }

    public func validate(in source: [UInt8]) throws {
        try location.validate(in: source)
        for item in related { try item.location.validate(in: source) }
        for fix in fixes { try fix.validate(in: source) }
    }
}

/// One provider's findings over an exact immutable source/configuration. The
/// caller adds its session/text stamp and rejects late results before display.
/// IDs and node indices are never identities across edits.
public struct DiagnosticReport: Sendable {
    public let source: [UInt8]
    public let provider: String
    public let providerVersion: String
    public let dialect: String
    public let configurationID: String
    public let findings: [DocumentDiagnostic]

    /// Stable ordering: document first, then original offsets, severity (errors
    /// first), code and message key. Equal keys retain provider emission order.
    public init(source: [UInt8], provider: String, providerVersion: String, dialect: String,
                configurationID: String, findings: [DocumentDiagnostic]) throws {
        guard !provider.isEmpty, !providerVersion.isEmpty, !dialect.isEmpty, !configurationID.isEmpty,
              findings.allSatisfy({ $0.provider == provider }) else { throw DiagnosticError.invalidIdentifier }
        for finding in findings { try finding.validate(in: source) }
        func offset(_ finding: DocumentDiagnostic) -> Int {
            switch finding.location {
            case .document: -1
            case .source(let range): range.lowerBound
            case .line(let start): start
            }
        }
        self.source = source
        self.provider = provider
        self.providerVersion = providerVersion
        self.dialect = dialect
        self.configurationID = configurationID
        self.findings = findings.enumerated().sorted { a, b in
            let left = a.element
            let right = b.element
            if offset(left) != offset(right) { return offset(left) < offset(right) }
            if left.severity != right.severity { return left.severity.rawValue > right.severity.rawValue }
            if left.code != right.code { return left.code < right.code }
            if left.message.key != right.message.key { return left.message.key < right.message.key }
            return a.offset < b.offset
        }.map(\.element)
    }
}
