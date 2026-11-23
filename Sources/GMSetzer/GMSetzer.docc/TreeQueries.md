# Query and walk a syntax tree

Inspect a validated snapshot using its existing public query APIs.

## Walk in tree order

`Document.nodes` is flat storage, not a promise of preorder/source order.
Use child/sibling links or `children(of:)` to visit the actual structure:

```swift
import GMSetzer

let document = MarkdownParser().parse("# Title\n\n- First\n- Second\n")
var pending = [0]
var visited: [Int] = []
while let index = pending.popLast() {
    visited.append(index)
    let node = document.nodes[index]
    // Inspect node.kind, node.data and its original-byte range here.
    pending.append(contentsOf: document.children(of: index).reversed())
}
```

The root is always index zero. `children(of:)` requires a valid index in this
document. Reversing children before pushing preserves sibling order when
using a stack. To skip a subtree, omit that node's child append. This walk
includes custom nodes and metadata; the caller chooses any filtering policy.
Document validation establishes reachability and prevents cycles.

## Prefer specialised queries when appropriate

```swift
let index = DocumentIndex(document)
let headings = index.outline()
let caretNode = index.node(atUTF8Offset: 2, affinity: .downstream)
let parent = caretNode.flatMap { index.parent(of: $0) }
let ancestors = caretNode.map { Array(index.ancestors(of: $0)) }
```

Caret queries require exact source boundaries. `parent(of:)` returns nil for
the root or an invalid index. `outline()` already computes heading order and
hierarchy, including headings inside containers. `plainText(of:)` produces
semantic text while excluding raw HTML and opaque custom content.

## Build and transform explicitly

`DocumentBuilder` supports appending/finalising nodes over a known source;
`build()` validates the result before exposing an immutable `Document`.
Custom parser transforms must retain the exact original bytes and honour their
namespaces and token ownership. A source edit needs a fresh parse or a correctly
rebuilt snapshot; existing node indices and positions cannot be reused blindly.

The 1.0 query surface supports these use cases without requiring a visitor
protocol. Public visitor/rewriter conveniences and a Markdown writer remain
possible additive extensions after 1.0; they do not imply automatic source
editing, lossless formatting or incremental reparsing.
