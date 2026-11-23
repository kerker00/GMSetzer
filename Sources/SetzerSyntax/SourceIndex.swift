/// One-based physical line and Unicode-scalar column. A tab counts as one;
/// combining scalars count separately. This is neither a UTF-16 column (as
/// used by LSP) nor a visual caret column; use utf16Offset for UTF-16 APIs.
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
    private let source: [UInt8]
    /// Total replacement-decoded UTF-16 code units, including original line endings.
    public let utf16Count: Int
    private struct Checkpoint: Sendable {
        var byte: Int
        var utf16: Int
        var line: Int
        var column: Int
    }
    private struct StoredPoint<Word: FixedWidthInteger & Sendable>: Sendable {
        let byte: Word, utf16: Word, line: Word, column: Word
        init(_ point: Checkpoint) {
            byte = Word(point.byte); utf16 = Word(point.utf16)
            line = Word(point.line); column = Word(point.column)
        }
        var point: Checkpoint { Checkpoint(byte: Int(byte), utf16: Int(utf16), line: Int(line), column: Int(column)) }
    }
    private enum Points: Sendable {
        case compact([StoredPoint<Int32>]), wide([StoredPoint<Int>])
        var count: Int { switch self { case .compact(let p): p.count; case .wide(let p): p.count } }
        subscript(_ index: Int) -> Checkpoint {
            switch self { case .compact(let p): p[index].point; case .wide(let p): p[index].point }
        }
    }
    private let checkpoints: Points
    /// Physical line count, including an empty final line after a terminator.
    public let lineCount: Int

    /// Owns this document's original byte snapshot. Bare ranges do not carry
    /// identity: callers must not mix offsets from different snapshots.
    public init(_ document: Document) { self.init(document.source) }

    /// Raw-byte entry point for consumers that need positions before parsing.
    public init(_ source: [UInt8]) {
        self.source = source
        if source.count < Int32.max {
            let (points, end): ([StoredPoint<Int32>], Checkpoint) = Self.build(source)
            checkpoints = .compact(points); utf16Count = end.utf16; lineCount = end.line
        } else {
            let (points, end): ([StoredPoint<Int>], Checkpoint) = Self.build(source)
            checkpoints = .wide(points); utf16Count = end.utf16; lineCount = end.line
        }
    }
    private static func build<Word: FixedWidthInteger & Sendable>(_ source: [UInt8]) -> ([StoredPoint<Word>], Checkpoint) {
        var point = Checkpoint(byte: 0, utf16: 0, line: 1, column: 1)
        var points = [StoredPoint<Word>(point)]
        points.reserveCapacity(max(1, source.count / 64))
        source.withUnsafeBufferPointer { buffer in
            var previous = 0
            while point.byte < buffer.count {
                let end = ByteSearch.asciiRunEnd(in: buffer, from: point.byte, to: previous + min(128, buffer.count - previous))
                if end > point.byte {
                    let length = end - point.byte
                    point.byte = end; point.utf16 += length; point.column += length
                } else {
                    advance(&point, source)
                }
                if point.column == 1 || point.byte - previous >= 128 {
                    points.append(StoredPoint(point)); previous = point.byte
                }
            }
        }
        return (points, point)
    }

    /// Original byte offset of a one-based physical line, including an empty
    /// final line. nil for an invalid line; no internal arrays are exposed.
    public func utf8Offset(ofLine line: Int) -> Int? {
        guard line > 0, line <= lineCount else { return nil }
        var low = 0, high = checkpoints.count
        while low < high {
            let mid = (low + high) / 2
            if checkpoints[mid].line < line { low = mid + 1 } else { high = mid }
        }
        return checkpoints[low].byte
    }

    /// Converts an original-byte boundary to a UTF-16 code-unit offset. Returns
    /// nil outside the snapshot or inside a decoded scalar/CRLF pair.
    public func utf16Offset(atUTF8Offset offset: Int) -> Int? { point(atByte: offset)?.utf16 }
    /// Returns a one-based physical line/scalar column for an exact byte boundary.
    /// Invalid boundaries return nil rather than being rounded.
    public func position(atUTF8Offset offset: Int) -> SourcePosition? {
        point(atByte: offset).map { SourcePosition(line: $0.line, column: $0.column) }
    }
    /// Converts an exact UTF-16 boundary to original bytes. Returns nil for
    /// out-of-range offsets, surrogate interiors or the interior of CRLF.
    public func utf8Offset(atUTF16Offset offset: Int) -> Int? {
        guard offset >= 0, offset <= utf16Count else { return nil }
        var point = checkpoints[checkpoint(before: offset, utf16: true)]
        // In an ASCII run one byte is one UTF-16 unit.
        walk(&point) { $0.utf16 < offset ? $0.byte + (offset - $0.utf16) : nil }
        return point.utf16 == offset ? point.byte : nil
    }
    /// Converts a one-based physical line/Unicode-scalar column to original bytes.
    /// Columns beyond a line's content/terminator boundary return nil.
    public func utf8Offset(at position: SourcePosition) -> Int? {
        guard position.line > 0, position.line <= lineCount, position.column > 0 else { return nil }
        var low = 0, high = checkpoints.count
        while low < high {
            let mid = (low + high) / 2, candidate = checkpoints[mid]
            if candidate.line < position.line || candidate.line == position.line && candidate.column <= position.column {
                low = mid + 1
            } else { high = mid }
        }
        var point = checkpoints[low - 1]
        let line = point.line
        // Runs stop before CR/LF, so a column past the line end ends on the
        // terminator (or EOF) and is rejected below.
        walk(&point) { $0.column < position.column && $0.line == line && $0.byte < source.count &&
            source[$0.byte] != 10 && source[$0.byte] != 13 ? $0.byte + (position.column - $0.column) : nil }
        return point.column == position.column && point.line == line ? point.byte : nil
    }
    /// Converts both original-byte endpoints without widening the selection.
    /// Returns nil if either endpoint is outside or not an addressable boundary.
    public func utf16Range(for range: SourceRange) -> UTF16Range? {
        guard let lower = utf16Offset(atUTF8Offset: range.lowerBound),
              let upper = utf16Offset(atUTF8Offset: range.upperBound) else { return nil }
        return UTF16Range(location: lower, length: upper - lower)
    }
    /// Converts both UTF-16 endpoints to a half-open original-byte range.
    /// Returns nil if either endpoint would require rounding.
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
        walk(&point) { $0.byte < offset ? offset : nil }
        return point.byte == offset ? point : nil
    }
    /// Advances `point` while `limit` returns the furthest byte an ASCII run
    /// may reach; non-ASCII scalars and line terminators decode one at a time.
    @inline(__always)
    private func walk(_ point: inout Checkpoint, _ limit: (Checkpoint) -> Int?) {
        source.withUnsafeBufferPointer { buffer in
            while let bound = limit(point) {
                let end = ByteSearch.asciiRunEnd(in: buffer, from: point.byte, to: min(bound, buffer.count))
                if end > point.byte {
                    let length = end - point.byte
                    point.byte = end; point.utf16 += length; point.column += length
                } else {
                    Self.advance(&point, source)
                }
            }
        }
    }

    /// UTF-8 decoding needs at most three preceding bytes to establish a
    /// boundary. Tree queries do not need to build the full position index.
    package static func isBoundary(_ offset: Int, in bytes: [UInt8]) -> Bool {
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
