/// A half-open range of UTF-8 byte offsets in the exact original snapshot.
/// Invalid UTF-8 and CRLF do not change these offsets. Position conversion
/// to UTF-16 and line/column coordinates is provided by `SourceIndex`.
public struct SourceRange: Hashable, Sendable {
    public let lowerBound: Int
    public let upperBound: Int

    /// Creates an ordered, non-negative range. The upper bound is exclusive.
    /// The caller must also ensure the range fits the intended snapshot.
    ///
    /// - Precondition: `0 <= lowerBound && lowerBound <= upperBound`.
    public init(_ lowerBound: Int, _ upperBound: Int) {
        precondition(lowerBound >= 0 && lowerBound <= upperBound,
                     "a source range must be non-negative and ordered")
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public var count: Int { upperBound - lowerBound }
    public var isEmpty: Bool { lowerBound == upperBound }
    public func contains(_ other: SourceRange) -> Bool {
        lowerBound <= other.lowerBound && other.upperBound <= upperBound
    }
}
