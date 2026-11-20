import SetzerSyntax

/// Original-byte cursor with a virtual suffix when part of a tab was consumed.
/// Tab stops use the absolute source column, including enclosing prefixes.
/// The cursor does not store the source buffer: callers pass it to each
/// reading method, so creating a cursor never retains or copies the snapshot.
internal struct SourceCursor: Sendable {
    let original: SourceLine
    let end: Int
    var offset: Int
    var column: Int
    var virtual: Int
    var virtualSourceOffset: Int?

    @inline(__always)
    init(line: SourceLine) {
        self.original = line
        self.end = line.contentRange.upperBound
        self.offset = line.contentRange.lowerBound
        self.column = line.column
        self.virtual = line.virtualIndentation
        self.virtualSourceOffset = line.virtualSourceOffset
    }

    var logicalColumn: Int { column - virtual }
    var atEnd: Bool { virtual == 0 && offset == end }
    @inline(__always)
    func byte(_ source: [UInt8]) -> UInt8? {
        if virtual > 0 { return 32 }
        return offset < end ? source[offset] : nil
    }
    var view: SourceLine {
        SourceLine(original: original, offset: offset, column: column, virtual: virtual,
                   virtualSourceOffset: virtual > 0 ? virtualSourceOffset : nil)
    }

    @inline(__always)
    mutating func advanceASCII() {
        if virtual > 0 {
            virtual -= 1
            if virtual == 0 { virtualSourceOffset = nil }
        } else if offset < end {
            offset += 1
            column += 1
        }
    }

    @discardableResult
    mutating func consumeIndentation(_ count: Int, in source: [UInt8]) -> Int {
        var remaining = count
        let existing = min(remaining, virtual)
        virtual -= existing
        remaining -= existing
        if virtual == 0 { virtualSourceOffset = nil }
        while remaining > 0 && offset < end {
            let byte = source[offset]
            guard byte == 32 || byte == 9 else { break }
            let width = byte == 9 ? 4 - column % 4 : 1
            let start = offset
            offset += 1
            column += width
            if width > remaining {
                virtual = width - remaining
                virtualSourceOffset = start
                remaining = 0
            } else { remaining -= width }
        }
        return count - remaining
    }

    @discardableResult
    @inline(__always)
    mutating func skipIndentation(in source: [UInt8]) -> Int {
        let start = logicalColumn
        virtual = 0
        virtualSourceOffset = nil
        while offset < end {
            let byte = source[offset]
            if byte == 32 { column += 1 }
            else if byte == 9 { column += 4 - column % 4 }
            else { break }
            offset += 1
        }
        return logicalColumn - start
    }
}
