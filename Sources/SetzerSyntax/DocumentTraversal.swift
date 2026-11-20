/// Linked-tree preorder with a depth-sized sibling stack. Block traversal
/// skips paragraph/heading inlines; custom subtrees can be excluded as opaque.
package struct DocumentTraversal: Sequence {
    let document: Document
    var blocksOnly = false
    var includeCustomContent = true
    package init(_ document: Document, blocksOnly: Bool = false, includeCustomContent: Bool = true) {
        self.document = document; self.blocksOnly = blocksOnly; self.includeCustomContent = includeCustomContent
    }
    package func makeIterator() -> Iterator { Iterator(traversal: self) }
    package struct Iterator: IteratorProtocol {
        let traversal: DocumentTraversal
        var current: Int? = 0
        var siblings: [Int] = []
        package mutating func next() -> Int? {
            guard let index = current else { return nil }
            let node = traversal.document.nodes[index]
            var descend = true
            switch node.data {
            case .custom(_, let role, _): descend = traversal.includeCustomContent && (!traversal.blocksOnly || role == .block)
            case .document, .blockQuote, .list, .listItem, .taskListItem: break
            default: descend = !traversal.blocksOnly
            }
            if descend, let child = node.firstChild {
                if let sibling = node.nextSibling { siblings.append(sibling) }
                current = child
            } else { current = node.nextSibling ?? siblings.popLast() }
            return index
        }
    }
}

extension Document {
    package func plainText(of index: Int) -> String {
        guard nodes.indices.contains(index) else { return "" }
        var output = "", pending = [index]
        while let index = pending.popLast() {
            switch nodes[index].data {
            case .text(let text), .code(let text): output += text
            case .softBreak, .hardBreak: output += " "
            case .htmlInline, .htmlBlock, .custom: break
            default:
                // Children are pushed in reverse without a temporary array.
                let start = pending.count
                var child = nodes[index].firstChild
                while let next = child { pending.append(next); child = nodes[next].nextSibling }
                pending[start...].reverse()
            }
        }
        return output
    }
}
