/// Optional O(nodes) parent table. It owns the immutable snapshot so indices
/// cannot accidentally be resolved against a newer document. This is not an
/// offset-search index; boundary-aware position queries belong to M3.
public struct DocumentIndex: Sendable {
    public let document: Document
    private let parents: [Int?]

    public init(_ document: Document) {
        self.document = document
        var parents = [Int?](repeating: nil, count: document.nodes.count)
        for (parent, node) in document.nodes.enumerated() {
            var child = node.firstChild
            while let index = child {
                parents[index] = parent
                child = document.nodes[index].nextSibling
            }
        }
        self.parents = parents
    }

    /// nil for the root or an index outside this snapshot.
    public func parent(of index: Int) -> Int? {
        parents.indices.contains(index) ? parents[index] : nil
    }

    /// Nearest parent first; excludes the queried node.
    public func ancestors(of index: Int) -> [Int] {
        var result: [Int] = []
        var next = parent(of: index)
        while let index = next { result.append(index); next = parent(of: index) }
        return result
    }
}
