/// Central development version for parser and native-provider result identity.
/// Bump together with behavior changes; this is not a published release tag.
public enum GMSetzerVersion {
    public static let current = "0.5.0-dev.3"
}

/// Extensible dialect identity. Configuration remains the parser's separate
/// responsibility; an identity alone never enables an extension.
public struct MarkdownDialect: Hashable, Sendable {
    public let identifier: String
    public init?(identifier: String) {
        guard !identifier.isEmpty else { return nil }
        self.identifier = identifier
    }
    public static let commonMark = MarkdownDialect(identifier: "commonmark")!
    public static let gfm = MarkdownDialect(identifier: "gfm")!
}
