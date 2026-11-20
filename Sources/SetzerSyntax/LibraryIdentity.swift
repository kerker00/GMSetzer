/// Central parser and native-provider result identity. Bump with behavior
/// changes; a release candidate identity does not imply that a tag is published.
public enum GMSetzerVersion {
    public static let current = "0.5.0"
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
