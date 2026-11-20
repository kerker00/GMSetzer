/// Optional O(nodes) parent and source-order child table. It owns the immutable snapshot so indices
/// cannot accidentally be resolved against a newer document. This is an
/// immutable index; all query results belong to this snapshot.
public struct DocumentIndex: Sendable {
    public let document: Document
    private let parents: [Int?]
    private let children: [[Int]]

    public init(_ document: Document) {
        self.document = document
        var parents = [Int?](repeating: nil, count: document.nodes.count)
        var children = [[Int]](repeating: [], count: document.nodes.count)
        for (parent, node) in document.nodes.enumerated() {
            var child = node.firstChild
            while let index = child {
                parents[index] = parent
                children[parent].append(index)
                child = document.nodes[index].nextSibling
            }
        }
        self.parents = parents
        self.children = children
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

public enum SourceAffinity: Sendable { case downstream, upstream }

public struct OutlineEntry: Hashable, Sendable {
    public let node: Int
    public let level: Int
    public let title: String
    public let range: SourceRange
    /// Node index of the nearest preceding heading with a smaller level.
    public let parentHeading: Int?
}

extension DocumentIndex {
    /// Deepest nonempty node at a valid source boundary. Downstream uses
    /// [start,end), upstream (start,end]. At EOF downstream returns the root;
    /// at BOF upstream returns the root. Empty nodes never capture a caret.
    public func node(atUTF8Offset offset: Int, affinity: SourceAffinity = .downstream) -> Int? {
        guard SourceIndex.isBoundary(offset, in: document.source) else { return nil }
        var current = 0
        while true {
            let siblings = children[current]
            var low = 0, high = siblings.count
            while low < high {
                let mid = (low + high) / 2
                let end = document.nodes[siblings[mid]].range.upperBound
                if affinity == .downstream ? end <= offset : end < offset { low = mid + 1 }
                else { high = mid }
            }
            var found: Int?
            while low < siblings.count {
                let candidate = siblings[low], range = document.nodes[candidate].range
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

    /// Source-order headings, including nested containers. Text/code and image
    /// labels contribute decoded plain text; raw HTML/custom leaves do not.
    public func outline() -> [OutlineEntry] {
        var result: [OutlineEntry] = [], headings: [(level: Int, node: Int)] = []
        var pending = [0]
        while let index = pending.popLast() {
            if case .heading(let level) = document.nodes[index].data {
                while let last = headings.last, last.level >= level { headings.removeLast() }
                result.append(OutlineEntry(node: index, level: level, title: plainText(of: index),
                                           range: document.nodes[index].range, parentHeading: headings.last?.node))
                headings.append((level, index))
            }
            pending.append(contentsOf: children[index].reversed())
        }
        return result
    }

    public func plainText(of index: Int) -> String {
        guard document.nodes.indices.contains(index) else { return "" }
        var output = "", pending = [index]
        while let index = pending.popLast() {
            switch document.nodes[index].data {
            case .text(let text), .code(let text): output += text
            case .softBreak, .hardBreak: output += " "
            case .htmlInline, .htmlBlock, .custom: break
            default: pending.append(contentsOf: children[index].reversed())
            }
        }
        return output
    }
}
