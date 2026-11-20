public import SetzerSyntax

/// Opaque, snapshot/controller-bound ownership. Callbacks may retain a handle,
/// but only handles supplied in the current context can close a delimiter.
public struct DelimiterHandle: Hashable, Sendable {
    public let owner: String
    public let offset: Int
    public let width: Int
    internal let identity: Identity
    internal final class Identity: Sendable {}

    internal init(owner: String, offset: Int, width: Int) {
        self.owner = owner; self.offset = offset; self.width = width; self.identity = Identity()
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity === rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(identity)) }
}

public enum DelimiterRequest: Sendable {
    case none
    /// One entire delimiter run. Partial custom-run consumption is rejected.
    case open(width: Int)
    case close(DelimiterHandle, width: Int)
}

/// Callback offsets/ranges address `input`, a projected UTF-8 leaf stream with
/// LF line endings. `originalRanges` converts them to the immutable source;
/// callers never need to guess offsets across quote/list prefixes or CRLF.
public struct InlineContext: Sendable {
    public let source: [UInt8]
    public let input: [UInt8]
    public let offset: Int
    public let options: [String: SyntaxValue]
    public let canOpen: Bool
    public let canClose: Bool
    public let runLength: Int
    public let openers: [DelimiterHandle]
    internal let projection: InlineInput

    public func originalRanges(for range: SourceRange) -> [SourceRange]? {
        guard range.upperBound <= input.count else { return nil }
        return projection.ranges(range.lowerBound, range.upperBound)
    }
}

public struct InlineMatch: Sendable {
    public let consumed: Int
    public let data: NodeData
    /// Optional children in projected input coordinates, inside this match.
    /// Delimiter matches obtain their children from the controlled stack.
    public let children: SourceRange?
    public let delimiter: DelimiterRequest
    /// Namespaced tokens in projected input coordinates, converted by the core.
    public let tokens: [BlockToken]

    public init(consumed: Int, data: NodeData, children: SourceRange? = nil,
                delimiter: DelimiterRequest = .none, tokens: [BlockToken] = []) {
        self.consumed = consumed; self.data = data; self.children = children
        self.delimiter = delimiter; self.tokens = tokens
    }
}

public struct InlineRule: Sendable {
    public typealias Matcher = @Sendable (InlineContext) -> InlineMatch?
    public let identifier: String
    public let trigger: UInt8
    public let priority: Int
    /// Explicit opt-in to complete `[` matches outside an open link/image
    /// bracket. Ordinary rules retain protected core bracket dispatch.
    public let allowsBracketSyntax: Bool
    public let match: Matcher
    /// Called once per document after block transforms, before any inlines.
    /// The returned matcher can share a snapshot's immutable lookup tables.
    public let prepare: (@Sendable (Document) -> Matcher)?

    public init(_ identifier: String, trigger: UInt8, priority: Int = 0, allowsBracketSyntax: Bool = false,
                match: @escaping Matcher) {
        self.identifier = identifier; self.trigger = trigger; self.priority = priority
        self.allowsBracketSyntax = allowsBracketSyntax; self.match = match; self.prepare = nil
    }

    public init(_ identifier: String, trigger: UInt8, priority: Int = 0, allowsBracketSyntax: Bool = false,
                prepare: @escaping @Sendable (Document) -> Matcher) {
        self.identifier = identifier; self.trigger = trigger; self.priority = priority
        self.allowsBracketSyntax = allowsBracketSyntax; self.match = { _ in nil }; self.prepare = prepare
    }
}

internal struct ActiveInlineRule: Sendable {
    let rule: InlineRule
    let identifier: String
    let descriptor: ExtensionDescriptor
    let options: [String: SyntaxValue]
    let order: Int
    var matcher: InlineRule.Matcher?
}
