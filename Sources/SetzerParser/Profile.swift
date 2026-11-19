public import SetzerSyntax

/// An ordered, reproducible extension selection. Closures belong to the
/// parser's registry, not to this hashable configuration value.
public struct ExtensionConfiguration: Hashable, Sendable {
    public let identifier: String
    public let options: [String: SyntaxValue]

    public init(_ identifier: String, options: [String: SyntaxValue] = [:]) {
        self.identifier = identifier
        self.options = options
    }
}

public struct Profile: Hashable, Sendable {
    public let name: String
    public let extensions: [ExtensionConfiguration]

    public init(name: String, extensions: [ExtensionConfiguration] = []) {
        self.name = name
        self.extensions = extensions
    }

    public static let commonMark = Profile(name: "commonmark")
}

/// A source line after enclosing container prefixes. All ranges address original
/// bytes. A partially consumed tab contributes virtual leading spaces.
public struct SourceLine: Hashable, Sendable {
    public let range: SourceRange
    public let contentRange: SourceRange
    public let physicalRange: SourceRange
    public let virtualIndentation: Int
    internal let column: Int
    internal let virtualSourceOffset: Int?

    internal init(_ start: Int, _ contentEnd: Int, _ end: Int) {
        range = SourceRange(start, end)
        contentRange = SourceRange(start, contentEnd)
        physicalRange = range
        virtualIndentation = 0
        column = 0
        virtualSourceOffset = nil
    }

    internal init(original: SourceLine, offset: Int, column: Int, virtual: Int, virtualSourceOffset: Int?) {
        self.physicalRange = original.physicalRange
        self.contentRange = SourceRange(offset, original.contentRange.upperBound)
        self.range = SourceRange(virtualSourceOffset ?? offset, original.range.upperBound)
        self.column = column
        self.virtualIndentation = virtual
        self.virtualSourceOffset = virtualSourceOffset
    }
}

/// Immutable borrowed-by-value views; arrays share storage through Swift COW.
public struct BlockContext: Sendable {
    public let source: [UInt8]
    public let lineIndex: Int
    public let options: [String: SyntaxValue]
    public let line: SourceLine
    public let lineCount: Int
    internal let project: @Sendable (Int) -> SourceLine?

    /// Returns nil at EOF or a container boundary. Multi-line rules must stay
    /// within the current quote/item, including on blank continuation lines.
    public func line(at index: Int) -> SourceLine? { project(index) }
}

public struct ParserLimits: Hashable, Sendable {
    /// Counts quote, list and item nodes; lists require two slots. Parsing is
    /// iterative, and the limit bounds prefix work per physical source line.
    public let maximumContainerDepth: Int

    public init(maximumContainerDepth: Int = 128) {
        precondition((1...256).contains(maximumContainerDepth), "container depth must be between 1 and 256")
        self.maximumContainerDepth = maximumContainerDepth
    }
}

/// The first extension hook supports custom leaf blocks. Container continuation,
/// inline delimiters and post-processing will be added with those parser phases.
public struct BlockMatch: Sendable {
    public let consumedLines: Int
    public let data: NodeData
    public let sourceSegments: [SourceRange]

    public init(consumedLines: Int, data: NodeData, sourceSegments: [SourceRange] = []) {
        self.consumedLines = consumedLines
        self.data = data
        self.sourceSegments = sourceSegments
    }
}

public struct BlockRule: Sendable {
    public let identifier: String
    public let priority: Int
    /// Optional first non-space/tab byte, used to avoid unnecessary callbacks.
    public let trigger: UInt8?
    /// Whether this rule can start a new block in a running paragraph.
    public let interruptsParagraph: Bool
    public let match: @Sendable (BlockContext) -> BlockMatch?

    public init(_ identifier: String, priority: Int = 0, trigger: UInt8? = nil,
                interruptsParagraph: Bool = false,
                match: @escaping @Sendable (BlockContext) -> BlockMatch?) {
        self.identifier = identifier
        self.priority = priority
        self.trigger = trigger
        self.interruptsParagraph = interruptsParagraph
        self.match = match
    }
}

public struct MarkdownExtension: Sendable {
    public let identifier: String
    public let blockRules: [BlockRule]

    public init(_ identifier: String, blockRules: [BlockRule]) {
        self.identifier = identifier
        self.blockRules = blockRules
    }
}
