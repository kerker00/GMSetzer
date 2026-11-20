/// A stable node name. Custom kinds should use a namespace such as `math.block`.
public struct NodeKind: Hashable, Sendable, CustomStringConvertible {
    public let name: String
    public init(_ name: String) { self.name = name }
    public var description: String { name }

    public static let document = NodeKind("document")
    public static let paragraph = NodeKind("paragraph")
    public static let heading = NodeKind("heading")
    public static let text = NodeKind("text")
    public static let softBreak = NodeKind("softBreak")
    public static let hardBreak = NodeKind("hardBreak")
    public static let code = NodeKind("code")
    public static let emphasis = NodeKind("emphasis")
    public static let strong = NodeKind("strong")
    public static let link = NodeKind("link")
    public static let image = NodeKind("image")
    public static let htmlInline = NodeKind("htmlInline")
    public static let thematicBreak = NodeKind("thematicBreak")
    public static let codeBlock = NodeKind("codeBlock")
    public static let referenceDefinition = NodeKind("referenceDefinition")
    public static let blockQuote = NodeKind("blockQuote")
    public static let list = NodeKind("list")
    public static let listItem = NodeKind("listItem")
    public static let htmlBlock = NodeKind("htmlBlock")

    public static let builtins: Set<NodeKind> = [
        .document, .paragraph, .heading, .text, .softBreak, .hardBreak,
        .code, .emphasis, .strong, .link, .image, .htmlInline,
        .thematicBreak, .codeBlock, .referenceDefinition, .blockQuote, .list, .listItem, .htmlBlock,
    ]
}

/// The structural category used when validating parent-child relationships.
public enum NodeRole: Hashable, Sendable { case block, inline }

/// Portable extension attributes, independent of a parser or renderer module.
public indirect enum SyntaxValue: Hashable, Sendable {
    case string(String)
    case integer(Int)
    case boolean(Bool)
    case array([SyntaxValue])
    case object([String: SyntaxValue])
}

/// Source-spelled definition. The inline phase decodes destinations/titles and
/// folds labels for lookup; the retained payload itself is never rewritten.
public struct ReferenceDefinition: Hashable, Sendable {
    public let rawLabel: String
    public let rawDestination: String
    public let rawTitle: String?

    public init(rawLabel: String, rawDestination: String, rawTitle: String? = nil) {
        self.rawLabel = rawLabel
        self.rawDestination = rawDestination
        self.rawTitle = rawTitle
    }
}

/// Opt-in source-spelled components, not offsets in decoded label/title text.
/// Empty components retain a zero-length source range for insertion markers.
public struct ReferenceSyntax: Hashable, Sendable {
    public let label: [SourceRange]
    public let destination: [SourceRange]
    public let title: [SourceRange]
    public let markers: [SourceRange]

    public init(label: [SourceRange], destination: [SourceRange], title: [SourceRange], markers: [SourceRange]) {
        self.label = label
        self.destination = destination
        self.title = title
        self.markers = markers
    }
}

public enum ListStyle: Hashable, Sendable {
    case bullet(marker: UInt8)
    case ordered(start: Int, delimiter: UInt8)
}

public struct ListAttributes: Hashable, Sendable {
    public let style: ListStyle
    public let isTight: Bool

    public init(style: ListStyle, isTight: Bool = true) {
        self.style = style
        self.isTight = isTight
    }
}

/// Semantic data determines the kind, avoiding mismatched kind/payload pairs.
/// More built-in cases arrive with the corresponding parser implementation.
public enum NodeData: Hashable, Sendable {
    case document
    case paragraph
    case heading(level: Int)
    case text(String)
    case softBreak
    case hardBreak
    case code(String)
    case emphasis
    case strong
    case link(destination: String, title: String?)
    case image(destination: String, title: String?)
    case htmlInline(String)
    case thematicBreak
    case codeBlock(info: String?, literal: String)
    case referenceDefinition(ReferenceDefinition)
    case blockQuote
    case list(ListAttributes)
    case listItem
    case htmlBlock(HTMLBlock)
    case custom(kind: NodeKind, role: NodeRole, attributes: [String: SyntaxValue])

    public var kind: NodeKind {
        switch self {
        case .document: .document
        case .paragraph: .paragraph
        case .heading: .heading
        case .text: .text
        case .softBreak: .softBreak
        case .hardBreak: .hardBreak
        case .code: .code
        case .emphasis: .emphasis
        case .strong: .strong
        case .link: .link
        case .image: .image
        case .htmlInline: .htmlInline
        case .thematicBreak: .thematicBreak
        case .codeBlock: .codeBlock
        case .referenceDefinition: .referenceDefinition
        case .blockQuote: .blockQuote
        case .list: .list
        case .listItem: .listItem
        case .htmlBlock: .htmlBlock
        case .custom(let kind, _, _): kind
        }
    }

    public var role: NodeRole {
        switch self {
        case .text, .softBreak, .hardBreak, .code, .emphasis, .strong, .link, .image, .htmlInline: .inline
        case .custom(_, let role, _): role
        default: .block
        }
    }

    /// Custom kinds never use built-in names (validated before traversal),
    /// so matching cases is equivalent to comparing kind names.
    fileprivate func permits(_ child: NodeData) -> Bool {
        switch self {
        case .document, .blockQuote, .listItem:
            child.role == .block && !child.isDocumentOrListItem
        case .list: child.isListItem
        case .paragraph, .heading, .emphasis, .strong, .link, .image: child.role == .inline
        case .custom(_, .block, _): !child.isDocumentOrListItem
        case .custom(_, .inline, _): child.role == .inline
        default: false
        }
    }

    private var isDocumentOrListItem: Bool {
        switch self {
        case .document, .listItem: true
        default: false
        }
    }

    private var isListItem: Bool {
        if case .listItem = self { return true }
        return false
    }
}

/// Source segments of one node. Most nodes have none or exactly one, so
/// those are stored inline instead of in a heap-allocated array.
package enum SourceSegments: Hashable, Sendable {
    case none
    case one(SourceRange)
    case many([SourceRange])

    @inline(__always)
    package init(_ ranges: [SourceRange]) {
        switch ranges.count {
        case 0: self = .none
        case 1: self = .one(ranges[0])
        default: self = .many(ranges)
        }
    }

    package var array: [SourceRange] {
        switch self {
        case .none: []
        case .one(let range): [range]
        case .many(let ranges): ranges
        }
    }

    /// Checks containment in `range` and source order without allocating.
    @inline(__always)
    fileprivate func ordered(within range: SourceRange) -> Bool {
        switch self {
        case .none: return true
        case .one(let segment): return range.contains(segment)
        case .many(let segments):
            var previousEnd = range.lowerBound
            for segment in segments {
                guard range.contains(segment), segment.lowerBound >= previousEnd else { return false }
                previousEnd = segment.upperBound
            }
            return true
        }
    }
}

/// Flat tree node. Ranges include syntax; source segments identify contributing
/// content in the original byte buffer and may exclude prefixes or delimiters.
public struct Node: Hashable, Sendable {
    public let data: NodeData
    public var kind: NodeKind { data.kind }
    public let range: SourceRange
    package let segments: SourceSegments
    public var sourceSegments: [SourceRange] { segments.array }
    public internal(set) var firstChild: Int?
    public internal(set) var nextSibling: Int?

    public init(data: NodeData, range: SourceRange, sourceSegments: [SourceRange] = [],
                firstChild: Int? = nil, nextSibling: Int? = nil) {
        self.init(data: data, range: range, segments: SourceSegments(sourceSegments),
                  firstChild: firstChild, nextSibling: nextSibling)
    }

    @inline(__always)
    package init(data: consuming NodeData, range: SourceRange, segments: SourceSegments,
                 firstChild: Int? = nil, nextSibling: Int? = nil) {
        self.data = data
        self.range = range
        self.segments = segments
        self.firstChild = firstChild
        self.nextSibling = nextSibling
    }
}

public enum DocumentError: Error, Equatable, Sendable {
    case invalidRoot
    case invalidRange(node: Int)
    case invalidSegments(node: Int)
    case invalidIndex(node: Int, target: Int)
    case repeatedNode(Int)
    case unreachableNode(Int)
    case invalidPayload(node: Int)
    case invalidChild(parent: Int, child: Int)
    case unorderedSiblings(node: Int)
    case invalidParent(Int)
    case invalidFallback(node: Int)
    case invalidToken(Int)
    case invalidDiagnostic(Int)
}

public struct ParseDiagnostic: Hashable, Sendable {
    public enum Code: Hashable, Sendable {
        case invalidExtensionResult(String)
        case extensionFinding(owner: String, code: String, message: String)
        case nestingLimitExceeded(Int)
    }
    public let code: Code
    public let range: SourceRange

    public init(_ code: Code, range: SourceRange) {
        self.code = code
        self.range = range
    }
}

/// Immutable, validated source snapshot and syntax tree. Root index is zero.
public struct Document: Sendable {
    public let source: [UInt8]
    public let nodes: [Node]
    public private(set) var diagnostics: [ParseDiagnostic]
    /// nil means syntax collection was disabled; [] is a collected empty table.
    public let tokens: [SyntaxToken]?
    /// Projected, replacement-decoded text for unknown custom leaves. Kept
    /// separately so built-in nodes and semantic source segments do not grow.
    /// Values are plain text; renderers must escape them.
    public let customLeafFallbacks: [Int: String]

    public init(source: [UInt8], nodes: [Node], diagnostics: [ParseDiagnostic] = [],
                customLeafFallbacks: [Int: String] = [:], tokens: [SyntaxToken]? = nil) throws {
        guard let root = nodes.first, root.data == .document,
              root.range == SourceRange(0, source.count), root.nextSibling == nil else {
            throw DocumentError.invalidRoot
        }
        // Read fields in place: binding whole nodes would copy and release
        // their payloads once per node in both passes.
        try nodes.withUnsafeBufferPointer { nodes in
            let count = nodes.count
            for index in 0..<count {
                let range = nodes[index].range
                guard range.upperBound <= source.count else {
                    throw DocumentError.invalidRange(node: index)
                }
                guard nodes[index].segments.ordered(within: range) else {
                    throw DocumentError.invalidSegments(node: index)
                }
                if let target = nodes[index].firstChild, !(0..<count).contains(target) {
                    throw DocumentError.invalidIndex(node: index, target: target)
                }
                if let target = nodes[index].nextSibling, !(0..<count).contains(target) {
                    throw DocumentError.invalidIndex(node: index, target: target)
                }
                switch nodes[index].data {
                case .paragraph, .text, .softBreak, .thematicBreak, .codeBlock, .referenceDefinition,
                     .blockQuote, .listItem, .htmlBlock:
                    break
                case .heading(let level) where !(1...6).contains(level):
                    throw DocumentError.invalidPayload(node: index)
                case .custom(let kind, _, _) where kind.name.isEmpty || NodeKind.builtins.contains(kind):
                    throw DocumentError.invalidPayload(node: index)
                case .document where index != 0:
                    throw DocumentError.invalidPayload(node: index)
                case .list(let attributes):
                    switch attributes.style {
                    case .bullet(let marker) where !(marker == 42 || marker == 43 || marker == 45):
                        throw DocumentError.invalidPayload(node: index)
                    case .ordered(let start, let delimiter)
                        where !(0...999_999_999).contains(start) || !(delimiter == 46 || delimiter == 41):
                        throw DocumentError.invalidPayload(node: index)
                    default: break
                    }
                default: break
                }
            }
            // Node indices are dense and have all been bounds-checked above.
            // Avoid hashing and per-node temporary arrays in this linear pass.
            var visited = [Bool](repeating: false, count: count)
            var pending: [(index: Int, parent: Int)] = []
            pending.reserveCapacity(64)
            visited[0] = true
            if let child = nodes[0].firstChild { pending.append((child, 0)) }
            while let (index, parent) = pending.popLast() {
                guard !visited[index] else { throw DocumentError.repeatedNode(index) }
                visited[index] = true
                let range = nodes[index].range
                guard nodes[parent].range.contains(range) else {
                    throw DocumentError.invalidRange(node: index)
                }
                guard nodes[parent].data.permits(nodes[index].data) else {
                    throw DocumentError.invalidChild(parent: parent, child: index)
                }
                if let sibling = nodes[index].nextSibling {
                    guard range.upperBound <= nodes[sibling].range.lowerBound else {
                        // Check repeated nodes first, so self-cycles have a precise error.
                        if visited[sibling] { throw DocumentError.repeatedNode(sibling) }
                        throw DocumentError.unorderedSiblings(node: index)
                    }
                    pending.append((sibling, parent))
                }
                if let child = nodes[index].firstChild { pending.append((child, index)) }
            }
            if let unreachable = visited.firstIndex(of: false) {
                throw DocumentError.unreachableNode(unreachable)
            }
        }
        for index in customLeafFallbacks.keys {
            guard nodes.indices.contains(index), case .custom = nodes[index].data,
                  nodes[index].firstChild == nil else { throw DocumentError.invalidFallback(node: index) }
        }
        self.source = source
        self.nodes = nodes
        self.diagnostics = diagnostics
        if let tokens {
            try tokens.withUnsafeBufferPointer { tokens in
                for index in 0..<tokens.count {
                    let owner = tokens[index].owner
                    guard !tokens[index].role.isEmpty, nodes.indices.contains(owner),
                          nodes[owner].range.contains(tokens[index].range) else {
                        throw DocumentError.invalidToken(index)
                    }
                }
            }
        }
        for (index, diagnostic) in diagnostics.enumerated() where diagnostic.range.upperBound > source.count {
            throw DocumentError.invalidDiagnostic(index)
        }
        self.tokens = tokens
        self.customLeafFallbacks = customLeafFallbacks
    }

    /// Preserve the already validated snapshot on a rejected runtime transform.
    package func reportingInvalidExtension(_ identifier: String) -> Document {
        var copy = self
        copy.appendRuntimeIssue(identifier)
        return copy
    }

    private mutating func appendRuntimeIssue(_ identifier: String) {
        diagnostics.append(ParseDiagnostic(.invalidExtensionResult(identifier), range: root.range))
    }

    public var root: Node { nodes[0] }

    /// Node indices remain valid for the lifetime of this document only.
    public func children(of index: Int) -> [Int] {
        precondition(nodes.indices.contains(index), "node index belongs to this document")
        var result: [Int] = []
        var child = nodes[index].firstChild
        while let current = child {
            result.append(current)
            child = nodes[current].nextSibling
        }
        return result
    }
}

/// O(1) append to an existing parent; one O(nodes + segments) validation at build.
/// Mutable construction never exposes an incomplete `Document` to other modules.
public struct DocumentBuilder: Sendable {
    private let source: [UInt8]
    private var nodes: [Node]
    private var lastChildren: [Int?]
    private var diagnostics: [ParseDiagnostic] = []
    private var customLeafFallbacks: [Int: String] = [:]
    private var tokens: [SyntaxToken]?

    public init(source: [UInt8], collectSyntaxDetails: Bool = false) {
        self.tokens = collectSyntaxDetails ? [] : nil
        self.source = source
        self.nodes = [Node(data: .document, range: SourceRange(0, source.count))]
        self.lastChildren = [nil]
    }

    /// Capacity hint for parsers that can estimate the node count.
    package mutating func reserveCapacity(_ count: Int) {
        nodes.reserveCapacity(count)
        lastChildren.reserveCapacity(count)
    }

    /// A fallback literal is plain text for a custom leaf, independent of its
    /// semantic source segments. build() checks the owning node.
    @discardableResult
    public mutating func append(_ data: NodeData, range: SourceRange,
                                sourceSegments: [SourceRange] = [], fallbackLiteral: String? = nil,
                                to parent: Int = 0) throws -> Int {
        try append(data, range: range, segments: SourceSegments(sourceSegments), fallbackLiteral: fallbackLiteral, to: parent)
    }

    @discardableResult
    @inline(__always)
    package mutating func append(_ data: consuming NodeData, range: SourceRange, segments: SourceSegments,
                                 fallbackLiteral: String? = nil, to parent: Int = 0) throws -> Int {
        guard parent >= 0 && parent < nodes.count else { throw DocumentError.invalidParent(parent) }
        let index = nodes.count
        nodes.append(Node(data: data, range: range, segments: segments))
        lastChildren.append(nil)
        if let last = lastChildren[parent] { nodes[last].nextSibling = index }
        else { nodes[parent].firstChild = index }
        lastChildren[parent] = index
        if let fallbackLiteral { customLeafFallbacks[index] = fallbackLiteral }
        return index
    }

    public mutating func report(_ diagnostic: ParseDiagnostic) { diagnostics.append(diagnostic) }

    /// A no-op when collection is disabled. Ownership/ranges are checked at build.
    public mutating func record(_ token: SyntaxToken) { tokens?.append(token) }

    /// Explicit removal avoids finish() silently losing projected text.
    public mutating func clearFallback(for index: Int) { customLeafFallbacks[index] = nil }

    /// Complete an open block while retaining its topology. Validation occurs
    /// at build(), before an immutable Document can escape the builder.
    /// A supplied fallback replaces metadata; omission preserves it. Use
    /// clearFallback(for:) when changing a custom leaf into a container.
    public mutating func finish(_ index: Int, data: NodeData, range: SourceRange,
                                sourceSegments: [SourceRange] = [], fallbackLiteral: String? = nil) throws {
        guard index > 0 && nodes.indices.contains(index) else { throw DocumentError.invalidParent(index) }
        nodes[index] = Node(data: data, range: range, segments: SourceSegments(sourceSegments),
                            firstChild: nodes[index].firstChild, nextSibling: nodes[index].nextSibling)
        if let fallbackLiteral { customLeafFallbacks[index] = fallbackLiteral }
    }

    public func build() throws -> Document {
        try Document(source: source, nodes: nodes, diagnostics: diagnostics, customLeafFallbacks: customLeafFallbacks, tokens: tokens)
    }
}
