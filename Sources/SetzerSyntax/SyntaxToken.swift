/// A source-spelled role owned by a node in one immutable document snapshot.
/// Tokens may overlap (for example a marker and a semantic component), and
/// empty ranges are retained for insertion points. Array order is emission order.
public struct SyntaxToken: Hashable, Sendable {
    public let role: String
    public let range: SourceRange
    public let owner: Int

    public init(_ role: String, range: SourceRange, owner: Int) {
        self.role = role
        self.range = range
        self.owner = owner
    }
}

extension Document {
    /// Compatibility view of reference components over the generic token table.
    /// nil means collection was disabled; collected empty components survive.
    public func referenceSyntax(for owner: Int) -> ReferenceSyntax? {
        guard nodes.indices.contains(owner), nodes[owner].kind == .referenceDefinition,
              let tokens else { return nil }
        func ranges(_ role: String) -> [SourceRange] {
            tokens.compactMap { $0.owner == owner && $0.role == role ? $0.range : nil }
        }
        return ReferenceSyntax(label: ranges("core.reference.label"),
            destination: ranges("core.reference.destination"), title: ranges("core.reference.title"),
            markers: ranges("core.reference.marker"))
    }
}
