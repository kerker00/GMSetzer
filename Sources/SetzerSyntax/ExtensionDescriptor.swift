/// Portable metadata shared by parser, renderer and caller catalogs.
public struct ExtensionDescriptor: Hashable, Sendable {
    public let identifier: String
    public let version: String
    public let nodeKinds: Set<NodeKind>
    public let options: [String: ExtensionOption]

    public init(_ identifier: String, version: String = "1", nodeKinds: Set<NodeKind>,
                options: [String: ExtensionOption] = [:]) {
        self.identifier = identifier
        self.version = version
        self.nodeKinds = nodeKinds
        self.options = options
    }

    public func owns(_ identifier: String) -> Bool {
        identifier == self.identifier || identifier.hasPrefix(self.identifier + ".")
    }
}

/// An extension option schema. Type, finite allowed values and an optional
/// integer range are checked by the registry; defaults do not select grammar.
public struct ExtensionOption: Hashable, Sendable {
    /// Supported portable `SyntaxValue` categories for an option.
    public enum ValueType: Hashable, Sendable { case boolean, integer, string, array, object }
    public let type: ValueType
    public let defaultValue: SyntaxValue?
    public let allowedValues: Set<SyntaxValue>?
    public let integerRange: ClosedRange<Int>?

    public init(_ type: ValueType, defaultValue: SyntaxValue? = nil,
                allowedValues: Set<SyntaxValue>? = nil, integerRange: ClosedRange<Int>? = nil) {
        self.type = type
        self.defaultValue = defaultValue
        self.allowedValues = allowedValues
        self.integerRange = integerRange
    }

    public func accepts(_ value: SyntaxValue) -> Bool {
        switch (type, value) {
        case (.boolean, .boolean), (.string, .string), (.array, .array), (.object, .object): break
        case (.integer, .integer(let number)):
            if let integerRange, !integerRange.contains(number) { return false }
        default: return false
        }
        return allowedValues?.contains(value) ?? true
    }
}

/// Configuration has no source range and must never become an editor underline.
public struct ConfigurationIssue: Hashable, Sendable {
    /// Stable categories for rejected extension descriptors, options and rule IDs.
    public enum Code: Hashable, Sendable {
        case duplicateIdentifier, unavailableExtension, invalidDescriptor
        case namespaceViolation, unknownOption, invalidOption, unknownRule
    }
    public let code: Code
    public let identifier: String
    public let detail: String

    public init(_ code: Code, identifier: String, detail: String = "") {
        self.code = code
        self.identifier = identifier
        self.detail = detail
    }
}

/// The configuration issues rejected by a strict parser's `validated()` call.
public struct ConfigurationError: Error, Equatable, Sendable {
    public let issues: [ConfigurationIssue]
    public init(_ issues: [ConfigurationIssue]) { self.issues = issues }
}
