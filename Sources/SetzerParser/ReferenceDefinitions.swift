import SetzerSyntax

/// Scans only the leading definitions in an already collected paragraph. The
/// input is a view of original ranges, not a reconstructed Markdown document.
internal struct ReferenceScanner {
    struct Position: Equatable {
        var line: Int
        var offset: Int
    }
    /// Source-spelled components as positions; the caller emits tokens in
    /// label, destination, title, marker order without temporary arrays.
    struct Syntax {
        let label: (Position, Position)
        let destination: (Position, Position)
        let title: (Position, Position)?
        let markers: Markers
    }
    /// At most seven one-byte markers: [ ] : < > and a title pair.
    struct Markers {
        private(set) var count = 0
        private var offsets: (Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0)

        mutating func append(_ position: Position) {
            precondition(count < 7, "a reference definition has at most seven markers")
            switch count {
            case 0: offsets.0 = position.offset
            case 1: offsets.1 = position.offset
            case 2: offsets.2 = position.offset
            case 3: offsets.3 = position.offset
            case 4: offsets.4 = position.offset
            case 5: offsets.5 = position.offset
            default: offsets.6 = position.offset
            }
            count += 1
        }

        func forEach(_ body: (SourceRange) -> Void) {
            for index in 0..<count {
                let offset: Int
                switch index {
                case 0: offset = offsets.0
                case 1: offset = offsets.1
                case 2: offset = offsets.2
                case 3: offset = offsets.3
                case 4: offset = offsets.4
                case 5: offset = offsets.5
                default: offset = offsets.6
                }
                body(SourceRange(offset, offset + 1))
            }
        }
    }
    struct Match {
        let syntax: Syntax?
        let definition: ReferenceDefinition
        let firstLine: Int
        let endLine: Int
    }

    let source: [UInt8]
    let content: [SourceRange]
    let endings: [Int]
    let collectSyntax: Bool

    func byte(_ position: Position) -> UInt8? {
        guard position.line < content.count else { return nil }
        let range = content[position.line]
        return position.offset < range.upperBound ? source[position.offset] : 10
    }
    func advance(_ position: inout Position) {
        guard position.line < content.count else { return }
        if position.offset < content[position.line].upperBound { position.offset += 1 }
        else {
            position.line += 1
            if position.line < content.count { position.offset = content[position.line].lowerBound }
        }
    }
    func horizontal(_ position: inout Position) {
        while let byte = byte(position), byte == 32 || byte == 9 { advance(&position) }
    }
    func separator(_ position: inout Position) {
        horizontal(&position)
        if byte(position) == 10 { advance(&position); horizontal(&position) }
    }
    func punctuation(_ byte: UInt8) -> Bool {
        (33...47).contains(byte) || (58...64).contains(byte) || (91...96).contains(byte) || (123...126).contains(byte)
    }
    func escaped(_ position: inout Position) -> Bool {
        guard byte(position) == 92 else { return false }
        var next = position
        advance(&next)
        guard let byte = byte(next), punctuation(byte) else { return false }
        position = next
        advance(&position)
        return true
    }
    /// Per-line source ranges of a component; an empty component yields one
    /// empty range at its position.
    func forEachSegment(_ bounds: (Position, Position), _ body: (SourceRange) -> Void) {
        let (start, end) = bounds
        if start == end { body(SourceRange(start.offset, start.offset)); return }
        for line in start.line...min(end.line, content.count - 1) {
            let lower = line == start.line ? start.offset : content[line].lowerBound
            let upper = line == end.line ? end.offset : endings[line]
            if upper > lower { body(SourceRange(lower, upper)) }
        }
    }
    /// The bytes between two positions, with each passed line end read as
    /// LF and NUL replaced by U+FFFD. Copies whole line slices at once.
    func text(_ start: Position, _ end: Position) -> String {
        guard start != end, start.line < content.count else { return "" }
        let lastLine = min(end.line, content.count - 1)
        return source.withUnsafeBufferPointer { buffer in
            if start.line == end.line {
                let bytes = UnsafeBufferPointer(rebasing: buffer[start.offset..<end.offset])
                if !bytes.contains(0) { return String(decoding: bytes, as: UTF8.self) }
            }
            var bytes: [UInt8] = []
            for line in start.line...lastLine {
                let lower = line == start.line ? start.offset : content[line].lowerBound
                let upper = line == end.line ? end.offset : content[line].upperBound
                if upper > lower {
                    BlockParser.appendRepaired(UnsafeBufferPointer(rebasing: buffer[lower..<upper]), to: &bytes)
                }
                if line != end.line { bytes.append(10) }
            }
            return String(decoding: bytes, as: UTF8.self)
        }
    }

    /// Label limits: at most 999 scalars and at least one non-whitespace
    /// scalar. ASCII labels avoid Unicode property lookups.
    func acceptsLabel(_ label: String) -> Bool {
        var scalars = 0
        var visible = false
        for byte in label.utf8 {
            guard byte < 0x80 else {
                return label.unicodeScalars.count <= 999
                    && label.unicodeScalars.contains(where: { ![UInt32(9), 10, 13, 32].contains($0.value) })
            }
            scalars += 1
            if ![UInt8(9), 10, 13, 32].contains(byte) { visible = true }
        }
        return scalars <= 999 && visible
    }

    func parse(at line: Int) -> Match? {
        guard line < content.count else { return nil }
        var cursor = Position(line: line, offset: content[line].lowerBound)
        guard byte(cursor) == 91 else { return nil }
        var markers = Markers()
        markers.append(cursor)
        advance(&cursor)
        let labelStart = cursor
        var labelBytes = 0
        while let byte = byte(cursor), byte != 93 {
            guard byte != 91, labelBytes <= 3_996 else { return nil }
            if escaped(&cursor) { labelBytes += 2 }
            else { advance(&cursor); labelBytes += 1 }
        }
        guard byte(cursor) == 93 else { return nil }
        let labelEnd = cursor
        let label = text(labelStart, labelEnd)
        guard acceptsLabel(label) else { return nil }
        markers.append(cursor)
        advance(&cursor)
        guard byte(cursor) == 58 else { return nil }
        markers.append(cursor)
        advance(&cursor)
        separator(&cursor)

        let destinationStart: Position
        let destinationEnd: Position
        if byte(cursor) == 60 {
            markers.append(cursor)
            advance(&cursor)
            destinationStart = cursor
            while let byte = byte(cursor), byte != 62 {
                guard byte != 60 && byte != 10 else { return nil }
                if !escaped(&cursor) { advance(&cursor) }
            }
            guard byte(cursor) == 62 else { return nil }
            destinationEnd = cursor
            markers.append(cursor)
            advance(&cursor)
        } else {
            destinationStart = cursor
            var depth = 0
            while let byte = byte(cursor), byte != 32 && byte != 9 && byte != 10 {
                if byte != 0 && (byte < 32 || byte == 127) { return nil }
                if escaped(&cursor) { continue }
                if byte == 40 { depth += 1 }
                if byte == 41 { depth -= 1; if depth < 0 { return nil } }
                advance(&cursor)
            }
            guard depth == 0, cursor != destinationStart else { return nil }
            destinationEnd = cursor
        }
        let afterDestination = cursor
        horizontal(&cursor)
        guard byte(cursor) == 10 || byte(cursor) == nil || cursor != afterDestination else { return nil }
        let baseEndLine = cursor.line + 1
        let hasTrailingText = byte(cursor) != 10 && byte(cursor) != nil
        var titleCursor = cursor
        separator(&titleCursor)
        var titleBounds: (Position, Position)?
        var endLine = baseEndLine
        if let opening = byte(titleCursor), opening == 34 || opening == 39 || opening == 40 {
            let titleOnLaterLine = titleCursor.line > afterDestination.line
            let openingPosition = titleCursor
            let closing: UInt8 = opening == 40 ? 41 : opening
            advance(&titleCursor)
            let titleStart = titleCursor
            while let byte = byte(titleCursor), byte != closing {
                if opening == 40 && byte == 40 { break }
                if !escaped(&titleCursor) { advance(&titleCursor) }
            }
            if byte(titleCursor) == closing {
                let titleEnd = titleCursor
                let closingPosition = titleCursor
                advance(&titleCursor)
                horizontal(&titleCursor)
                if byte(titleCursor) == 10 || byte(titleCursor) == nil {
                    titleBounds = (titleStart, titleEnd)
                    endLine = titleCursor.line + 1
                    markers.append(openingPosition); markers.append(closingPosition)
                } else if !titleOnLaterLine { return nil }
            } else if !titleOnLaterLine { return nil }
        } else if hasTrailingText { return nil }
        // Malformed next-line title candidates do not invalidate a complete
        // destination line. They remain paragraph source for the caller.
        if hasTrailingText && titleBounds == nil { return nil }
        let syntax = collectSyntax ? Syntax(label: (labelStart, labelEnd), destination: (destinationStart, destinationEnd),
            title: titleBounds, markers: markers) : nil
        let definition = ReferenceDefinition(rawLabel: label, rawDestination: text(destinationStart, destinationEnd),
            rawTitle: titleBounds.map { text($0.0, $0.1) })
        return Match(syntax: syntax, definition: definition, firstLine: line, endLine: min(endLine, content.count))
    }
}
