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
    public static let thematicBreak = NodeKind("thematicBreak")
    public static let codeBlock = NodeKind("codeBlock")
    public static let referenceDefinition = NodeKind("referenceDefinition")
    public static let blockQuote = NodeKind("blockQuote")
    public static let list = NodeKind("list")
    public static let listItem = NodeKind("listItem")
    public static let htmlBlock = NodeKind("htmlBlock")

    public static let builtins: Set<NodeKind> = [
        .document, .paragraph, .heading, .text, .softBreak,
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

/// Unresolved source spelling. M2 will decode destinations/titles and perform
/// Unicode case folding of labels when resolving references.
public struct ReferenceDefinition: Hashable, Sendable {
    public let rawLabel: String
    public let rawDestination: String
    public let rawTitle: String?
    public let syntax: ReferenceSyntax?

    public init(rawLabel: String, rawDestination: String, rawTitle: String? = nil, syntax: ReferenceSyntax? = nil) {
        self.rawLabel = rawLabel
        self.rawDestination = rawDestination
        self.rawTitle = rawTitle
        self.syntax = syntax
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
        case .text, .softBreak: .inline
        case .custom(_, let role, _): role
        default: .block
        }
    }

    fileprivate func permits(_ child: NodeData) -> Bool {
        switch self {
        case .document, .blockQuote, .listItem:
            child.role == .block && child.kind != .document && child.kind != .listItem
        case .list: child.kind == .listItem
        case .paragraph, .heading: child.role == .inline
        case .custom(_, .block, _): child.kind != .document && child.kind != .listItem
        case .custom(_, .inline, _): child.role == .inline
        default: false
        }
    }
}

/// Flat tree node. Ranges include syntax; source segments identify contributing
/// content in the original byte buffer and may exclude prefixes or delimiters.
public struct Node: Hashable, Sendable {
    public let data: NodeData
    public var kind: NodeKind { data.kind }
    public let range: SourceRange
    public let sourceSegments: [SourceRange]
    public internal(set) var firstChild: Int?
    public internal(set) var nextSibling: Int?

    public init(data: NodeData, range: SourceRange, sourceSegments: [SourceRange] = [],
                firstChild: Int? = nil, nextSibling: Int? = nil) {
        self.data = data
        self.range = range
        self.sourceSegments = sourceSegments
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
}

public struct ParseDiagnostic: Hashable, Sendable {
    public enum Code: Hashable, Sendable {
        case unsupportedExtension(String)
        case duplicateRegistration(String)
        case invalidExtensionResult(String)
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
    public let diagnostics: [ParseDiagnostic]
    /// Projected, replacement-decoded text for unknown custom leaves. Kept
    /// separately so built-in nodes and semantic source segments do not grow.
    /// Values are plain text; renderers must escape them.
    public let customLeafFallbacks: [Int: String]

    public init(source: [UInt8], nodes: [Node], diagnostics: [ParseDiagnostic] = [],
                customLeafFallbacks: [Int: String] = [:]) throws {
        guard let root = nodes.first, root.data == .document,
              root.range == SourceRange(0, source.count), root.nextSibling == nil else {
            throw DocumentError.invalidRoot
        }
        for (index, node) in nodes.enumerated() {
            guard node.range.upperBound <= source.count else {
                throw DocumentError.invalidRange(node: index)
            }
            var previousEnd = node.range.lowerBound
            for segment in node.sourceSegments {
                guard node.range.contains(segment), segment.lowerBound >= previousEnd else {
                    throw DocumentError.invalidSegments(node: index)
                }
                previousEnd = segment.upperBound
            }
            if case .referenceDefinition(let reference) = node.data, let syntax = reference.syntax {
                for ranges in [syntax.label, syntax.destination, syntax.title, syntax.markers] {
                    var end = node.range.lowerBound
                    for range in ranges {
                        guard node.range.contains(range), range.lowerBound >= end else {
                            throw DocumentError.invalidSegments(node: index)
                        }
                        end = range.upperBound
                    }
                }
            }
            for target in [node.firstChild, node.nextSibling].compactMap({ $0 }) {
                guard nodes.indices.contains(target) else {
                    throw DocumentError.invalidIndex(node: index, target: target)
                }
            }
            switch node.data {
            case .heading(let level) where !(1...6).contains(level):
                throw DocumentError.invalidPayload(node: index)
            case .custom(let kind, _, _) where kind.name.isEmpty || NodeKind.builtins.contains(kind):
                throw DocumentError.invalidPayload(node: index)
            case .document where index != 0:
                throw DocumentError.invalidPayload(node: index)
            case .list(let attributes):
                switch attributes.style {
                case .bullet(let marker) where ![UInt8(42), 43, 45].contains(marker):
                    throw DocumentError.invalidPayload(node: index)
                case .ordered(let start, let delimiter)
                    where !(0...999_999_999).contains(start) || ![UInt8(46), 41].contains(delimiter):
                    throw DocumentError.invalidPayload(node: index)
                default: break
                }
            default: break
            }
        }
        var visited = Set<Int>()
        var pending: [(index: Int, parent: Int?)] = [(0, nil)]
        while let (index, parent) = pending.popLast() {
            guard visited.insert(index).inserted else { throw DocumentError.repeatedNode(index) }
            let node = nodes[index]
            if let parent {
                guard nodes[parent].range.contains(node.range) else {
                    throw DocumentError.invalidRange(node: index)
                }
                guard nodes[parent].data.permits(node.data) else {
                    throw DocumentError.invalidChild(parent: parent, child: index)
                }
            }
            if let sibling = node.nextSibling {
                guard node.range.upperBound <= nodes[sibling].range.lowerBound else {
                    // Check repeated nodes first, so self-cycles have a precise error.
                    if visited.contains(sibling) { throw DocumentError.repeatedNode(sibling) }
                    throw DocumentError.unorderedSiblings(node: index)
                }
                pending.append((sibling, parent))
            }
            if let child = node.firstChild { pending.append((child, index)) }
        }
        if let unreachable = nodes.indices.first(where: { !visited.contains($0) }) {
            throw DocumentError.unreachableNode(unreachable)
        }
        for index in customLeafFallbacks.keys {
            guard nodes.indices.contains(index), case .custom = nodes[index].data,
                  nodes[index].firstChild == nil else { throw DocumentError.invalidFallback(node: index) }
        }
        self.source = source
        self.nodes = nodes
        self.diagnostics = diagnostics
        self.customLeafFallbacks = customLeafFallbacks
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

    public init(source: [UInt8]) {
        self.source = source
        self.nodes = [Node(data: .document, range: SourceRange(0, source.count))]
        self.lastChildren = [nil]
    }

    /// A fallback literal is plain text for a custom leaf, independent of its
    /// semantic source segments. build() checks the owning node.
    @discardableResult
    public mutating func append(_ data: NodeData, range: SourceRange,
                                sourceSegments: [SourceRange] = [], fallbackLiteral: String? = nil,
                                to parent: Int = 0) throws -> Int {
        guard nodes.indices.contains(parent) else { throw DocumentError.invalidParent(parent) }
        let index = nodes.count
        nodes.append(Node(data: data, range: range, sourceSegments: sourceSegments))
        lastChildren.append(nil)
        if let last = lastChildren[parent] { nodes[last].nextSibling = index }
        else { nodes[parent].firstChild = index }
        lastChildren[parent] = index
        if let fallbackLiteral { customLeafFallbacks[index] = fallbackLiteral }
        return index
    }

    public mutating func report(_ diagnostic: ParseDiagnostic) { diagnostics.append(diagnostic) }

    /// Complete an open block while retaining its topology. Validation occurs
    /// at build(), before an immutable Document can escape the builder.
    /// Replaces fallback metadata too; nil clears a previous fallback.
    public mutating func finish(_ index: Int, data: NodeData, range: SourceRange,
                                sourceSegments: [SourceRange] = [], fallbackLiteral: String? = nil) throws {
        guard index > 0 && nodes.indices.contains(index) else { throw DocumentError.invalidParent(index) }
        let old = nodes[index]
        nodes[index] = Node(data: data, range: range, sourceSegments: sourceSegments,
                            firstChild: old.firstChild, nextSibling: old.nextSibling)
        customLeafFallbacks[index] = fallbackLiteral
    }

    public func build() throws -> Document {
        try Document(source: source, nodes: nodes, diagnostics: diagnostics, customLeafFallbacks: customLeafFallbacks)
    }
}
