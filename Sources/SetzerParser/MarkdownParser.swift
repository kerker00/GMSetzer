public import SetzerSyntax

/// A named set of syntax extensions with their options, such as strict
/// CommonMark or GitHub Flavored Markdown.
public struct Profile: Hashable, Sendable {
    public let name: String

    public init(name: String) { self.name = name }

    /// The CommonMark specification without extensions.
    public static let commonMark = Profile(name: "commonmark")
}

/// Parses Markdown into a `Document`.
///
/// Milestone M0: the parser only produces the document node; block and
/// inline parsing follow in M1 and M2.
public struct MarkdownParser: Sendable {
    public let profile: Profile

    public init(profile: Profile = .commonMark) {
        self.profile = profile
    }

    public func parse(_ text: String) -> Document {
        let bytes = Array(text.utf8)
        return Document(source: bytes, nodes: [Node(kind: .document, range: SourceRange(0, bytes.count))])
    }
}
