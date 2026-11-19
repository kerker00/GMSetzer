/// The kind of a syntax node. CommonMark and GFM kinds are predefined;
/// extensions register their own kinds by name, so new syntax never needs
/// a change to this library.
public struct NodeKind: Hashable, Sendable, CustomStringConvertible {
    public let name: String

    public init(_ name: String) { self.name = name }

    public var description: String { name }

    public static let document = NodeKind("document")
}

/// One node of a document, stored flat: children and siblings are indices
/// into `Document.nodes`, so a tree is one array of values.
public struct Node: Hashable, Sendable {
    public var kind: NodeKind
    /// Where the node comes from in the source.
    public var range: SourceRange
    public var firstChild: Int?
    public var nextSibling: Int?

    public init(kind: NodeKind, range: SourceRange, firstChild: Int? = nil, nextSibling: Int? = nil) {
        self.kind = kind
        self.range = range
        self.firstChild = firstChild
        self.nextSibling = nextSibling
    }
}

/// A parsed Markdown document: the source as UTF-8 bytes and its syntax
/// tree. A value: safe to send between threads and cheap to keep.
public struct Document: Sendable {
    /// The text the document was parsed from.
    public let source: [UInt8]
    /// All nodes; the root is at index 0.
    public internal(set) var nodes: [Node]

    public init(source: [UInt8], nodes: [Node]) {
        precondition(nodes.first?.kind == .document, "the root of a document is a document node")
        self.source = source
        self.nodes = nodes
    }

    public var root: Node { nodes[0] }

    /// The children of the node at `index`, in order.
    public func children(of index: Int) -> [Int] {
        var result: [Int] = []
        var child = nodes[index].firstChild
        while let current = child {
            result.append(current)
            child = nodes[current].nextSibling
        }
        return result
    }
}
