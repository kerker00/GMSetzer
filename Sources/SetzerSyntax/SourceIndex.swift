/// One-based physical line and Unicode-scalar column. A tab counts as one;
/// combining scalars count separately. This is not a visual caret column.
public struct SourcePosition: Hashable, Sendable {
    public let line: Int
    public let column: Int
    public init(line: Int, column: Int) { self.line = line; self.column = column }
}

/// Portable UTF-16 code-unit range, independent of Foundation.
public struct UTF16Range: Hashable, Sendable {
    public let location: Int
    public let length: Int
    public init(location: Int, length: Int) {
        precondition(location >= 0 && length >= 0 && location <= Int.max - length)
        self.location = location; self.length = length
    }
}

/// Optional snapshot-bound index. Checkpoints use O(bytes / 128 + lines)
/// space; queries binary-search and decode at most one checkpoint interval.
/// Invalid UTF-8 follows Unicode maximal-subpart replacement decoding. CRLF
/// is one physical newline (two UTF-16 units) with no addressable interior.
public struct SourceIndex: Sendable {
    public let source: [UInt8]
    public let utf16Count: Int
    private struct Checkpoint: Sendable {
        var byte: Int
        var utf16: Int
        var line: Int
        var column: Int
    }
    private let checkpoints: [Checkpoint]
    public let lineStarts: [Int]

    public init(_ source: [UInt8]) {
        self.source = source
        var point = Checkpoint(byte: 0, utf16: 0, line: 1, column: 1)
        var points = [point]
        var starts = [0]
        while point.byte < source.count {
            let newline = source[point.byte] == 10 || source[point.byte] == 13
            Self.advance(&point, source)
            if newline { starts.append(point.byte) }
            if newline || point.byte - points[points.count - 1].byte >= 128 { points.append(point) }
        }
        self.checkpoints = points
        self.lineStarts = starts
        self.utf16Count = point.utf16
    }

    public func utf16Offset(atUTF8Offset offset: Int) -> Int? { point(atByte: offset)?.utf16 }
    public func position(atUTF8Offset offset: Int) -> SourcePosition? {
        point(atByte: offset).map { SourcePosition(line: $0.line, column: $0.column) }
    }
    public func utf8Offset(atUTF16Offset offset: Int) -> Int? {
        guard offset >= 0, offset <= utf16Count else { return nil }
        var point = checkpoints[checkpoint(before: offset, utf16: true)]
        while point.utf16 < offset { Self.advance(&point, source) }
        return point.utf16 == offset ? point.byte : nil
    }
    public func utf8Offset(at position: SourcePosition) -> Int? {
        guard position.line > 0, position.line <= lineStarts.count, position.column > 0 else { return nil }
        var low = 0, high = checkpoints.count
        while low < high {
            let mid = (low + high) / 2, candidate = checkpoints[mid]
            if candidate.line < position.line || candidate.line == position.line && candidate.column <= position.column {
                low = mid + 1
            } else { high = mid }
        }
        var point = checkpoints[low - 1]
        while point.column < position.column {
            guard point.byte < source.count, source[point.byte] != 10, source[point.byte] != 13 else { return nil }
            Self.advance(&point, source)
        }
        return point.byte
    }
    public func utf16Range(for range: SourceRange) -> UTF16Range? {
        guard let lower = utf16Offset(atUTF8Offset: range.lowerBound),
              let upper = utf16Offset(atUTF8Offset: range.upperBound) else { return nil }
        return UTF16Range(location: lower, length: upper - lower)
    }
    public func sourceRange(for range: UTF16Range) -> SourceRange? {
        guard let lower = utf8Offset(atUTF16Offset: range.location),
              let upper = utf8Offset(atUTF16Offset: range.location + range.length) else { return nil }
        return SourceRange(lower, upper)
    }
    private func checkpoint(before value: Int, utf16: Bool) -> Int {
        var low = 0, high = checkpoints.count
        while low < high {
            let mid = (low + high) / 2
            let candidate = utf16 ? checkpoints[mid].utf16 : checkpoints[mid].byte
            if candidate <= value { low = mid + 1 } else { high = mid }
        }
        return low - 1
    }
    private func point(atByte offset: Int) -> Checkpoint? {
        guard offset >= 0, offset <= source.count else { return nil }
        var point = checkpoints[checkpoint(before: offset, utf16: false)]
        while point.byte < offset { Self.advance(&point, source) }
        return point.byte == offset ? point : nil
    }
    /// UTF-8 decoding needs at most three preceding bytes to establish a
    /// boundary. Tree queries do not need to build the full position index.
    internal static func isBoundary(_ offset: Int, in bytes: [UInt8]) -> Bool {
        guard offset >= 0, offset <= bytes.count else { return false }
        if offset > 0, offset < bytes.count, bytes[offset - 1] == 13, bytes[offset] == 10 { return false }
        for start in max(0, offset - 3)..<offset where (0xC2...0xF4).contains(bytes[start]) {
            var point = Checkpoint(byte: start, utf16: 0, line: 1, column: 1)
            advance(&point, bytes)
            if point.byte > offset { return false }
        }
        return true
    }

    private static func advance(_ point: inout Checkpoint, _ bytes: [UInt8]) {
        let start = point.byte, first = bytes[start]
        if first == 10 || first == 13 {
            let count = first == 13 && start + 1 < bytes.count && bytes[start + 1] == 10 ? 2 : 1
            point.byte += count; point.utf16 += count
            point.line += 1; point.column = 1
            return
        }
        let width: Int
        switch first {
        case 0xC2...0xDF: width = 2
        case 0xE0...0xEF: width = 3
        case 0xF0...0xF4: width = 4
        default: width = 1
        }
        var consumed = 1
        if width > 1 {
            while consumed < width, start + consumed < bytes.count {
                let next = bytes[start + consumed]
                guard (0x80...0xBF).contains(next) else { break }
                if consumed == 1 {
                    if first == 0xE0 && next < 0xA0 || first == 0xED && next > 0x9F ||
                       first == 0xF0 && next < 0x90 || first == 0xF4 && next > 0x8F { break }
                }
                consumed += 1
            }
        }
        point.byte += consumed
        point.utf16 += width == 4 && consumed == width ? 2 : 1
        point.column += 1
    }
}
