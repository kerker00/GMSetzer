/// Optional snapshot-owned CSR index: one parent table, one child-offset table
/// and one flat child table. The common representation uses three Int32 arrays;
/// documents beyond Int32 capacity transparently use native-width tables.
public struct DocumentIndex: Sendable {
    /// Immutable owning snapshot for all indices returned by this index.
    public let document: Document
    fileprivate enum Tables: Sendable {
        case compact(parents: [Int32], starts: [Int32], children: [Int32])
        case wide(parents: [Int], starts: [Int], children: [Int])
        func parent(_ index: Int) -> Int {
            switch self { case .compact(let p, _, _): Int(p[index]); case .wide(let p, _, _): p[index] }
        }
        func bounds(_ index: Int) -> Range<Int> {
            switch self {
            case .compact(_, let s, _): Int(s[index])..<Int(s[index + 1])
            case .wide(_, let s, _): s[index]..<s[index + 1]
            }
        }
        func child(_ offset: Int) -> Int {
            switch self { case .compact(_, _, let c): Int(c[offset]); case .wide(_, _, let c): c[offset] }
        }
    }
    private let tables: Tables

    /// Builds optional parent/child lookup tables over an already validated tree.
    public init(_ document: Document) {
        self.document = document
        if document.nodes.count <= Int32.max {
            let (p, s, c): ([Int32], [Int32], [Int32]) = Self.build(document)
            tables = .compact(parents: p, starts: s, children: c)
        } else {
            let (p, s, c): ([Int], [Int], [Int]) = Self.build(document)
            tables = .wide(parents: p, starts: s, children: c)
        }
    }
    private static func build<Word: FixedWidthInteger & SignedInteger>(_ document: Document) -> ([Word], [Word], [Word]) {
        sequentialBuild(document) ?? linkedBuild(document)
    }

    /// Fast path for trees whose parents and earlier siblings precede each
    /// node, as every builder append produces: reads the node array strictly
    /// in order instead of chasing sibling links through it. Ascending child
    /// indices then equal sibling order. Returns nil for any other layout.
    private static func sequentialBuild<Word: FixedWidthInteger & SignedInteger>(_ document: Document) -> ([Word], [Word], [Word])? {
        let count = document.nodes.count
        var parents = [Word](repeating: -1, count: count)
        var starts = [Word](repeating: 0, count: count + 1)
        let ordered = document.nodes.withUnsafeBufferPointer { nodes -> Bool in
            for index in 0..<count {
                let parent = parents[index]
                if index > 0 {
                    guard parent >= 0 else { return false }
                    starts[Int(parent) + 1] += 1
                }
                if let child = nodes[index].firstChild {
                    guard child > index else { return false }
                    parents[child] = Word(index)
                }
                if let sibling = nodes[index].nextSibling {
                    guard sibling > index else { return false }
                    parents[sibling] = parent
                }
            }
            return true
        }
        guard ordered else { return nil }
        for index in 0..<count { starts[index + 1] += starts[index] }
        var cursors = starts
        var children = [Word](repeating: 0, count: count - 1)
        for index in 1..<max(1, count) {
            let parent = Int(parents[index])
            children[Int(cursors[parent])] = Word(index)
            cursors[parent] += 1
        }
        return (parents, starts, children)
    }

    private static func linkedBuild<Word: FixedWidthInteger & SignedInteger>(_ document: Document) -> ([Word], [Word], [Word]) {
        let count = document.nodes.count
        var parents = [Word](repeating: -1, count: count)
        var starts = [Word](repeating: 0, count: count + 1)
        for parent in 0..<count {
            var child = document.nodes[parent].firstChild
            while let index = child { starts[parent + 1] += 1; child = document.nodes[index].nextSibling }
        }
        for index in 0..<count { starts[index + 1] += starts[index] }
        var children = [Word](repeating: 0, count: count - 1)
        for parent in 0..<count {
            var cursor = Int(starts[parent]), child = document.nodes[parent].firstChild
            while let index = child {
                children[cursor] = Word(index); parents[index] = Word(parent)
                cursor += 1; child = document.nodes[index].nextSibling
            }
        }
        return (parents, starts, children)
    }

    /// Returns the snapshot-local parent, or nil for the root/an invalid index.
    public func parent(of index: Int) -> Int? {
        guard document.nodes.indices.contains(index) else { return nil }
        let parent = tables.parent(index)
        return parent < 0 ? nil : parent
    }

    /// Nearest parent first, excluding the node. Iteration allocates no array.
    public func ancestors(of index: Int) -> Ancestors { Ancestors(tables: tables, next: parent(of: index)) }
    /// Snapshot-owned parent-chain sequence, nearest ancestor first.
    public struct Ancestors: Sequence, Sendable {
        fileprivate let tables: Tables
        fileprivate let next: Int?
        public func makeIterator() -> Iterator { Iterator(tables: tables, current: next) }
        /// Walks one ancestor chain without allocating an intermediate array.
        public struct Iterator: IteratorProtocol {
            fileprivate let tables: Tables
            fileprivate var current: Int?
            public mutating func next() -> Int? {
                guard let result = current else { return nil }
                let parent = tables.parent(result)
                current = parent < 0 ? nil : parent
                return result
            }
        }
    }

    /// Deepest nonempty node at a valid source boundary. Downstream uses
    /// [start,end), upstream (start,end]. Downstream EOF/upstream BOF return
    /// the root; empty nodes never capture a caret.
    public func node(atUTF8Offset offset: Int, affinity: SourceAffinity = .downstream) -> Int? {
        guard SourceIndex.isBoundary(offset, in: document.source) else { return nil }
        var current = 0
        while true {
            let siblings = tables.bounds(current)
            var low = siblings.lowerBound, high = siblings.upperBound
            while low < high {
                let mid = (low + high) / 2
                let end = document.nodes[tables.child(mid)].range.upperBound
                if affinity == .downstream ? end <= offset : end < offset { low = mid + 1 }
                else { high = mid }
            }
            var found: Int?
            while low < siblings.upperBound {
                let candidate = tables.child(low), range = document.nodes[candidate].range
                if range.lowerBound > offset { break }
                if !range.isEmpty && (affinity == .downstream
                    ? range.lowerBound <= offset && offset < range.upperBound
                    : range.lowerBound < offset && offset <= range.upperBound) { found = candidate; break }
                low += 1
            }
            guard let found else { return current }
            current = found
        }
    }

    /// Global source-order headings, including quotes, lists and custom block
    /// containers. Parent headings can cross container boundaries. Paragraph
    /// inlines are never visited. Text/code/image labels form the plain title.
    public func outline() -> [OutlineEntry] {
        var result: [OutlineEntry] = [], headings: [(level: Int, node: Int)] = []
        for index in DocumentTraversal(document, blocksOnly: true) {
            guard case .heading(let level) = document.nodes[index].data else { continue }
            while let last = headings.last, last.level >= level { headings.removeLast() }
            result.append(OutlineEntry(node: index, level: level, title: plainText(of: index),
                                       range: document.nodes[index].range, parentHeading: headings.last?.node))
            headings.append((level, index))
        }
        return result
    }
    /// Joins semantic text/code/image labels and line breaks in a subtree,
    /// excluding raw HTML/custom payloads. An invalid index returns an empty string.
    public func plainText(of index: Int) -> String { document.plainText(of: index) }
}

/// Which adjacent source span owns a caret exactly at a boundary.
public enum SourceAffinity: Sendable { case downstream, upstream }
/// A source-ordered heading with a snapshot-local node and heading parent.
public struct OutlineEntry: Hashable, Sendable {
    public let node: Int
    public let level: Int
    public let title: String
    public let range: SourceRange
    public let parentHeading: Int?
}
