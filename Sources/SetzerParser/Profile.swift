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
    public let disabledRules: Set<String>
    /// Explicit precedence within opening/leaf phases; unspecified rules keep default order.
    public let ruleOrder: [String]

    public init(name: String, extensions: [ExtensionConfiguration] = [], disabledRules: Set<String> = [], ruleOrder: [String] = []) {
        self.name = name
        self.extensions = extensions
        self.disabledRules = disabledRules
        self.ruleOrder = ruleOrder
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

    /// Drop a syntax prefix made of ASCII bytes, retaining original columns,
    /// line endings and any remaining partial-tab indentation.
    public func droppingASCII(_ count: Int, from line: SourceLine) -> SourceLine? {
        guard count >= 0, line.virtualIndentation == 0,
              line.contentRange.count >= count, line.contentRange.upperBound <= source.count else { return nil }
        var cursor = SourceCursor(source: source, line: line)
        for _ in 0..<count {
            guard let byte = cursor.byte, byte < 128, byte != 9 else { return nil }
            cursor.advanceASCII()
        }
        return cursor.view
    }

    /// Remove up to columns of indentation using physical four-column tabs.
    public func droppingIndentation(_ columns: Int, from line: SourceLine) -> SourceLine? {
        guard columns >= 0, line.contentRange.upperBound <= source.count else { return nil }
        var cursor = SourceCursor(source: source, line: line)
        guard cursor.consumeIndentation(columns) == columns else { return nil }
        return cursor.view
    }

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

/// A complete block match. Optional projected child lines are parsed by the
/// core in the same source snapshot. The callback determines enter/continue/
/// finish and must stop at enclosing container boundaries.
public struct BlockMatch: Sendable {
    public let consumedLines: Int
    public let data: NodeData
    public let sourceSegments: [SourceRange]
    public let children: [SourceLine]?
    public let tokens: [BlockToken]
    public let diagnostics: [ParseDiagnostic]

    public init(consumedLines: Int, data: NodeData, sourceSegments: [SourceRange] = [],
                children: [SourceLine]? = nil, tokens: [BlockToken] = [], diagnostics: [ParseDiagnostic] = []) {
        self.consumedLines = consumedLines
        self.data = data
        self.sourceSegments = sourceSegments
        self.children = children
        self.tokens = tokens
        self.diagnostics = diagnostics
    }
}

/// Token ownership is assigned to the matched block after validation.
public struct BlockToken: Hashable, Sendable {
    public let role: String
    public let range: SourceRange
    public init(_ role: String, range: SourceRange) { self.role = role; self.range = range }
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
    public let descriptor: ExtensionDescriptor
    public var identifier: String { descriptor.identifier }
    public let blockRules: [BlockRule]
    public let transforms: [BlockTransform]

    public init(_ identifier: String, nodeKinds: Set<NodeKind>, options: [String: ExtensionOption] = [:], blockRules: [BlockRule] = [], transforms: [BlockTransform] = []) {
        self.init(descriptor: ExtensionDescriptor(identifier, nodeKinds: nodeKinds, options: options), blockRules: blockRules, transforms: transforms)
    }

    public init(descriptor: ExtensionDescriptor, blockRules: [BlockRule] = [], transforms: [BlockTransform] = []) {
        self.descriptor = descriptor
        self.blockRules = blockRules
        self.transforms = transforms
    }
}
