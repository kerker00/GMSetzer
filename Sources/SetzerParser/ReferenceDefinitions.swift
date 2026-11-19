import SetzerSyntax

/// Scans only the leading definitions in an already collected paragraph. The
/// input is a view of original ranges, not a reconstructed Markdown document.
internal struct ReferenceScanner {
    struct Position: Equatable {
        var line: Int
        var offset: Int
    }
    struct Match {
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
    func segments(_ start: Position, _ end: Position) -> [SourceRange] {
        if start == end { return [SourceRange(start.offset, start.offset)] }
        var result: [SourceRange] = []
        for line in start.line...min(end.line, content.count - 1) {
            let lower = line == start.line ? start.offset : content[line].lowerBound
            let upper = line == end.line ? end.offset : endings[line]
            if upper > lower { result.append(SourceRange(lower, upper)) }
        }
        return result
    }
    func text(_ start: Position, _ end: Position) -> String {
        var position = start
        var bytes: [UInt8] = []
        while position != end, let byte = byte(position) {
            if byte == 0 { bytes.append(contentsOf: [0xEF, 0xBF, 0xBD]) }
            else { bytes.append(byte) }
            advance(&position)
        }
        return String(decoding: bytes, as: UTF8.self)
    }
    func marker(_ position: Position, length: Int = 1) -> SourceRange {
        SourceRange(position.offset, position.offset + length)
    }

    func parse(at line: Int) -> Match? {
        guard line < content.count else { return nil }
        var cursor = Position(line: line, offset: content[line].lowerBound)
        guard byte(cursor) == 91 else { return nil }
        var markers = collectSyntax ? [marker(cursor)] : []
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
        guard label.unicodeScalars.count <= 999,
              label.unicodeScalars.contains(where: { !$0.properties.isWhitespace }) else { return nil }
        if collectSyntax { markers.append(marker(cursor)) }
        advance(&cursor)
        guard byte(cursor) == 58 else { return nil }
        if collectSyntax { markers.append(marker(cursor)) }
        advance(&cursor)
        separator(&cursor)

        let destinationStart: Position
        let destinationEnd: Position
        if byte(cursor) == 60 {
            if collectSyntax { markers.append(marker(cursor)) }
            advance(&cursor)
            destinationStart = cursor
            while let byte = byte(cursor), byte != 62 {
                guard byte != 60 && byte != 10 else { return nil }
                if !escaped(&cursor) { advance(&cursor) }
            }
            guard byte(cursor) == 62 else { return nil }
            destinationEnd = cursor
            if collectSyntax { markers.append(marker(cursor)) }
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
                    if collectSyntax { markers.append(marker(openingPosition)); markers.append(marker(closingPosition)) }
                } else if !titleOnLaterLine { return nil }
            } else if !titleOnLaterLine { return nil }
        } else if hasTrailingText { return nil }
        // Malformed next-line title candidates do not invalidate a complete
        // destination line. They remain paragraph source for the caller.
        if hasTrailingText && titleBounds == nil { return nil }
        let syntax = collectSyntax ? ReferenceSyntax(label: segments(labelStart, labelEnd),
            destination: segments(destinationStart, destinationEnd),
            title: titleBounds.map { segments($0.0, $0.1) } ?? [], markers: markers) : nil
        let definition = ReferenceDefinition(rawLabel: label, rawDestination: text(destinationStart, destinationEnd),
            rawTitle: titleBounds.map { text($0.0, $0.1) }, syntax: syntax)
        return Match(definition: definition, firstLine: line, endLine: min(endLine, content.count))
    }
}
