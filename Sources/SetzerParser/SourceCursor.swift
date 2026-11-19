import SetzerSyntax

/// Original-byte cursor with a virtual suffix when part of a tab was consumed.
/// Tab stops use the absolute source column, including enclosing prefixes.
internal struct SourceCursor: Sendable {
    let source: [UInt8]
    let original: SourceLine
    var offset: Int
    var column: Int
    var virtual: Int
    var virtualSourceOffset: Int?

    init(source: [UInt8], line: SourceLine) {
        self.source = source
        self.original = line
        self.offset = line.contentRange.lowerBound
        self.column = line.column
        self.virtual = line.virtualIndentation
        self.virtualSourceOffset = line.virtualSourceOffset
    }

    var logicalColumn: Int { column - virtual }
    var atEnd: Bool { virtual == 0 && offset == original.contentRange.upperBound }
    var byte: UInt8? {
        if virtual > 0 { return 32 }
        return offset < original.contentRange.upperBound ? source[offset] : nil
    }
    var view: SourceLine {
        SourceLine(original: original, offset: offset, column: column, virtual: virtual,
                   virtualSourceOffset: virtual > 0 ? virtualSourceOffset : nil)
    }

    mutating func advanceASCII() {
        if virtual > 0 {
            virtual -= 1
            if virtual == 0 { virtualSourceOffset = nil }
        } else if offset < original.contentRange.upperBound {
            offset += 1
            column += 1
        }
    }

    @discardableResult
    mutating func consumeIndentation(_ count: Int) -> Int {
        var remaining = count
        let existing = min(remaining, virtual)
        virtual -= existing
        remaining -= existing
        if virtual == 0 { virtualSourceOffset = nil }
        while remaining > 0 && offset < original.contentRange.upperBound {
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
    mutating func skipIndentation() -> Int {
        let start = logicalColumn
        virtual = 0
        virtualSourceOffset = nil
        while let byte, byte == 32 || byte == 9 {
            column += byte == 9 ? 4 - column % 4 : 1
            offset += 1
        }
        return logicalColumn - start
    }
}
