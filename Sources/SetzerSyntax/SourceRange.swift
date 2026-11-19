/// A range in the source text, as UTF-8 byte offsets from its start.
///
/// Byte offsets are what the parser works with; `LineIndex` converts them
/// to lines, columns and UTF-16 offsets for text views.
public struct SourceRange: Hashable, Sendable {
    public var lowerBound: Int
    public var upperBound: Int

    public init(_ lowerBound: Int, _ upperBound: Int) {
        precondition(lowerBound <= upperBound, "a source range must not be reversed")
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public var count: Int { upperBound - lowerBound }
    public var isEmpty: Bool { lowerBound == upperBound }
}
