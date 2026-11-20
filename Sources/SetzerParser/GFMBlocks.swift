import SetzerSyntax

// GFM tables and task list items. Recognition is ported from cmark-gfm's
// `extensions/table.c`, `tasklist.c` and `ext_scanners.re` as pinned in
// swift-cmark 08ddb528 (BSD-2-Clause, Copyright (c) 2014, John MacFarlane;
// see NOTICE) onto the projected line table: no reconstructed Markdown,
// every node maps to original bytes.

/// Mutable state of an open table leaf.
internal struct TableState {
    let alignments: [TableAlignment]
    var rows = 1
    /// Cells taken from the source; autocompleted cells are not counted.
    var parsedCells: Int
    /// cmark-gfm stops adding rows beyond this many autocompleted cells.
    static let maximumAutocompletedCells = 0x80000
    var autocompletedCells: Int { alignments.count * rows - parsedCells }
}

/// One parsed table row: raw cell ranges between pipes and the pipes.
internal struct TableRowScan {
    var cells: [SourceRange] = []
    var pipes: [Int] = []
}

extension BlockParser {
    /// `spacechar`: space, tab, vertical tab and form feed.
    @inline(__always)
    static func tableSpace(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 || byte == 11 || byte == 12 }

    /// `row_from_string` for one line whose content is `start..<end`; the
    /// end stands for the newline. `leadingPipe` is false when the line keeps
    /// leading whitespace (a paragraph continuation line in cmark-gfm).
    func scanTableRow(_ start: Int, _ end: Int, leadingPipe: Bool = true) -> TableRowScan? {
        var row = TableRowScan()
        let count = visitTableRow(start, end, leadingPipe: leadingPipe,
                                  cell: { row.cells.append($0) }, pipe: { row.pipes.append($0) })
        return count > 0 ? row : nil
    }

    /// Number of cells in a row, or 0 when the line is not a row.
    func countTableCells(_ start: Int, _ end: Int) -> Int {
        visitTableRow(start, end, leadingPipe: true, cell: { _ in }, pipe: { _ in })
    }

    /// Scans one row, reporting cells and pipes; returns the cell count, or 0
    /// when the line does not end as a row.
    @inline(__always)
    func visitTableRow(_ start: Int, _ end: Int, leadingPipe: Bool,
                       cell report: (SourceRange) -> Void, pipe reportPipe: (Int) -> Void) -> Int {
        var cells = 0
        var offset = start
        func pipeEnd(_ position: Int) -> Int {
            guard position < end, source[position] == 124 else { return 0 }
            var cursor = position + 1
            while cursor < end && Self.tableSpace(source[cursor]) { cursor += 1 }
            return cursor - position
        }
        if leadingPipe {
            let skipped = pipeEnd(offset)
            if skipped > 0 { reportPipe(offset) }
            offset += skipped
        }
        var more = true
        while offset <= end && more {
            // `(escaped_char | [^|\r\n])+` under longest-match semantics: a pipe
            // directly after any backslash in the cell belongs to the cell.
            var cellEnd = offset
            while cellEnd < end && (source[cellEnd] != 124 || (cellEnd > offset && source[cellEnd - 1] == 92)) {
                cellEnd += 1
            }
            let pipe = pipeEnd(cellEnd)
            if cellEnd > offset || pipe > 0 {
                cells += 1
                guard cells < Int(UInt16.max) else { return 0 }
                report(SourceRange(offset, cellEnd))
            }
            if pipe > 0 { reportPipe(cellEnd) }
            offset = cellEnd + pipe
            if pipe == 0 {
                var cursor = offset
                while cursor < end && Self.tableSpace(source[cursor]) { cursor += 1 }
                if cursor == end { offset = end + 1 }
                more = false
            }
        }
        return offset == end + 1 ? cells : 0
    }

    /// `scan_table_start` on the line's content from its first non-space.
    func tableDelimiterRow(_ index: Int) -> [TableAlignment]? {
        let start = indentation(index).offset, end = lines[index].contentRange.upperBound
        var cursor = start
        func marker() -> Bool {
            while cursor < end && Self.tableSpace(source[cursor]) { cursor += 1 }
            if cursor < end && source[cursor] == 58 { cursor += 1 }
            let dashes = cursor
            while cursor < end && source[cursor] == 45 { cursor += 1 }
            guard cursor > dashes else { return false }
            if cursor < end && source[cursor] == 58 { cursor += 1 }
            while cursor < end && Self.tableSpace(source[cursor]) { cursor += 1 }
            return true
        }
        if cursor < end && source[cursor] == 124 { cursor += 1 }
        guard marker() else { return nil }
        while cursor < end && source[cursor] == 124 {
            let saved = cursor
            cursor += 1
            if !marker() { cursor = saved; break }
        }
        if cursor < end && source[cursor] == 124 { cursor += 1 }
        while cursor < end && Self.tableSpace(source[cursor]) { cursor += 1 }
        guard cursor == end, let row = scanTableRow(start, end) else { return nil }
        return row.cells.map { cell in
            let content = tableCellContent(cell)
            guard let first = content.first, let last = content.last else { return .none }
            let left = source[first.lowerBound] == 58, right = source[last.upperBound - 1] == 58
            return left && right ? .center : left ? .left : right ? .right : .none
        }
    }

    /// The trimmed cell content when it contains no escaped pipe.
    @inline(__always)
    func plainCellContent(_ cell: SourceRange) -> SourceRange? {
        var lower = cell.lowerBound, upper = cell.upperBound
        for position in lower..<upper where source[position] == 124 { return nil }
        func trimmable(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 || byte == 10 || byte == 13 }
        while lower < upper && trimmable(source[lower]) { lower += 1 }
        while upper > lower && trimmable(source[upper - 1]) { upper -= 1 }
        return SourceRange(lower, upper)
    }

    /// The cell's semantic bytes: a backslash before a pipe is removed, then
    /// tab, LF, CR and space are trimmed (`unescape_pipes`, `cmark_strbuf_trim`).
    func tableCellContent(_ cell: SourceRange) -> [SourceRange] {
        var segments = unescapingPipes(cell)
        func trimmable(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 || byte == 10 || byte == 13 }
        while let first = segments.first {
            var lower = first.lowerBound
            while lower < first.upperBound && trimmable(source[lower]) { lower += 1 }
            if lower == first.upperBound { segments.removeFirst(); continue }
            segments[0] = SourceRange(lower, first.upperBound)
            break
        }
        while let last = segments.last {
            var upper = last.upperBound
            while upper > last.lowerBound && trimmable(source[upper - 1]) { upper -= 1 }
            if upper == last.lowerBound { segments.removeLast(); continue }
            segments[segments.count - 1] = SourceRange(last.lowerBound, upper)
            break
        }
        return segments
    }

    /// `unescape_pipes`: the source pieces of `range` without each backslash
    /// that directly precedes a pipe.
    func unescapingPipes(_ cell: SourceRange) -> [SourceRange] {
        var segments: [SourceRange] = []
        var runStart = cell.lowerBound
        var position = cell.lowerBound
        while position < cell.upperBound {
            if source[position] == 92, position + 1 < cell.upperBound, source[position + 1] == 124 {
                if position > runStart { segments.append(SourceRange(runStart, position)) }
                runStart = position + 1
                position += 2
            } else { position += 1 }
        }
        if cell.upperBound > runStart { segments.append(SourceRange(runStart, cell.upperBound)) }
        return segments
    }


    /// Turn the open paragraph's last line into a table header when `index`
    /// is a matching delimiter row. A failed paragraph is never rechecked.
    /// Rows start at their first non-space; a lazily continued header line
    /// keeps its whitespace after the matched containers, as in cmark-gfm.
    func tableRowStart(_ index: Int) -> Int {
        index == lazyParagraphLine ? lines[index].contentRange.lowerBound : indentation(index).offset
    }

    mutating func startTable(at index: Int) -> Bool {
        guard let paragraph = leaf, let alignments = tableDelimiterRow(index) else { return false }
        let header = paragraph.indices.upperBound - 1
        guard countTableCells(tableRowStart(header), lines[header].contentRange.upperBound) == alignments.count else {
            leaf?.tableChecked = true
            return false
        }
        if header > paragraph.indices.lowerBound {
            // cmark-gfm inserts the earlier lines as a finished paragraph:
            // reference definitions in it stay text, and `\|` loses its backslash.
            leaf?.indices = paragraph.indices.lowerBound..<header
            finishLeaf(tablePreamble: true)
        }
        leaf = OpenLeaf(kind: .table, parent: paragraph.parent, start: header, indices: header..<(index + 1))
        openTable = TableState(alignments: alignments, parsedCells: alignments.count)
        return true
    }

    /// A non-blank row continues the table unless the line starts another
    /// block (any core start, since a table is not a paragraph).
    mutating func continueTable(at index: Int) -> Bool {
        guard let state = openTable, !isBlank(index),
              state.autocompletedCells <= TableState.maximumAutocompletedCells,
              !startsBlockAfterTable(index) else { return false }
        let cells = countTableCells(indentation(index).offset, lines[index].contentRange.upperBound)
        guard cells > 0 else { return false }
        openTable?.rows += 1
        openTable?.parsedCells += min(cells, state.alignments.count)
        return true
    }

    private mutating func startsBlockAfterTable(_ index: Int) -> Bool {
        let first = firstByte(index)
        if first.columns >= 4 { return registry.contains(.indentedCode) }
        guard let byte = first.byte else { return false }
        switch byte {
        case 62: if registry.contains(.blockQuote) && Self.quoteContent(lines[index], source: source) != nil { return true }
        case 35: if registry.contains(.atxHeading) && atxHeading(index) != nil { return true }
        case 96, 126: if registry.contains(.fencedCode) && openingFence(index) != nil { return true }
        case 60: if registry.contains(.htmlBlock) && htmlBlockStart(index, interrupting: false) != nil { return true }
        default: break
        }
        if (byte == 42 || byte == 45 || byte == 95) && registry.contains(.thematicBreak) && thematicBreak(index) { return true }
        if Self.mayStartListItem(first) && registry.contains(.list) && listMarker(index, interrupting: false) != nil { return true }
        return !rules.isEmpty && extensionMatch(at: index, interrupting: false) != nil
    }

    /// Append the finished table: header, body rows padded or truncated to
    /// the header's column count. The delimiter row has no node.
    mutating func finishTable(_ active: OpenLeaf) {
        guard let state = openTable else { return }
        beginChild()
        let first = active.indices.lowerBound, last = active.indices.upperBound - 1
        let table = append(.table(TableAttributes(alignments: state.alignments)),
                           range: SourceRange(lines[first].range.lowerBound, lines[last].range.upperBound), to: active.parent)
        if collectSyntaxDetails {
            let delimiter = first + 1
            builder.record(SyntaxToken("gfm.table.delimiterRow",
                range: SourceRange(indentation(delimiter).offset, lines[delimiter].contentRange.upperBound), owner: table))
        }
        let columns = state.alignments.count
        let collect = collectSyntaxDetails
        // One pair of scratch buffers for every row of this table.
        var cells: [SourceRange] = [], pipes: [Int] = []
        cells.reserveCapacity(columns + 1)
        for index in active.indices where index != first + 1 {
            let isHeader = index == first
            cells.removeAll(keepingCapacity: true)
            pipes.removeAll(keepingCapacity: true)
            _ = visitTableRow(tableRowStart(index), lines[index].contentRange.upperBound, leadingPipe: true,
                              cell: { cells.append($0) }, pipe: { if collect { pipes.append($0) } })
            let row = append(.tableRow(isHeader: isHeader), range: lines[index].range, to: table)
            if collect {
                for pipe in pipes where pipe < (cells.count > columns ? cells[columns].lowerBound : Int.max) {
                    builder.record(SyntaxToken("gfm.table.pipe", range: SourceRange(pipe, pipe + 1), owner: row))
                }
            }
            for column in 0..<columns {
                let alignment = state.alignments[column]
                guard column < cells.count else {
                    // Cells completing a short row carry no alignment, as in
                    // cmark-gfm's output.
                    let end = lines[index].contentRange.upperBound
                    append(.tableCell(alignment: .none), range: SourceRange(end, end), to: row)
                    continue
                }
                if let plain = plainCellContent(cells[column]) {
                    // Common case: no escaped pipe, one trimmed range.
                    let cell = append(.tableCell(alignment: alignment), range: cells[column],
                                      segments: plain.isEmpty ? .none : .one(plain), to: row)
                    if !plain.isEmpty { append(.text(decode(plain)), range: plain, segments: .one(plain), to: cell) }
                    continue
                }
                let content = tableCellContent(cells[column])
                let cell = append(.tableCell(alignment: alignment), range: cells[column],
                                  segments: SourceSegments(content), to: row)
                guard let lower = content.first?.lowerBound, let upper = content.last?.upperBound else { continue }
                var bytes: [UInt8] = []
                for segment in content { appendRepaired(segment, to: &bytes) }
                append(.text(String(decoding: bytes, as: UTF8.self)), range: SourceRange(lower, upper),
                       segments: SourceSegments(content), to: cell)
            }
        }
    }

    /// cmark-gfm's `tasklist` pattern on the physical line:
    /// `spacechar* ("-"|"+"|"*"|[0-9]+ any) spacechar+ ("[ ]"|"[x]"|"[X]") spacechar+`,
    /// where the checkbox must begin the item content opened on this line.
    func taskListMarker(_ index: Int) -> (checked: Bool, range: SourceRange)? {
        let content = lines[index]
        let start = content.contentRange.lowerBound, end = content.contentRange.upperBound
        guard content.virtualIndentation == 0, start + 3 < end, source[start] == 91, source[start + 2] == 93,
              source[start + 1] == 32 || source[start + 1] == 120 || source[start + 1] == 88,
              Self.tableSpace(source[start + 3]) else { return nil }
        var cursor = content.physicalRange.lowerBound
        while cursor < start && Self.tableSpace(source[cursor]) { cursor += 1 }
        guard cursor < start else { return nil }
        if source[cursor] == 45 || source[cursor] == 43 || source[cursor] == 42 {
            cursor += 1
        } else {
            let digits = cursor
            while cursor < start && (48...57).contains(source[cursor]) { cursor += 1 }
            guard cursor > digits, cursor < start, source[cursor] != 10, source[cursor] != 13 else { return nil }
            cursor += 1
        }
        let spaces = cursor
        while cursor < start && Self.tableSpace(source[cursor]) { cursor += 1 }
        guard cursor > spaces, cursor == start else { return nil }
        return (source[start + 1] != 32, SourceRange(start, start + 3))
    }

    /// Paragraph lines before a table header, finished the way cmark-gfm
    /// inserts them: no reference definitions, pipes unescaped, content trimmed.
    mutating func finishTablePreamble(_ paragraphLines: Range<Int>, parent: Int) {
        beginChild()
        var lineSegments: [[SourceRange]] = []
        for index in paragraphLines {
            var content = SourceRange(indentation(index).offset, lines[index].contentRange.upperBound)
            if index == paragraphLines.upperBound - 1 { content = trimmed(content.lowerBound, content.upperBound) }
            lineSegments.append(unescapingPipes(content))
        }
        let all = lineSegments.flatMap { $0 }
        let first = paragraphLines.lowerBound, last = paragraphLines.upperBound - 1
        let node = append(.paragraph, range: SourceRange(lines[first].range.lowerBound, lines[last].range.upperBound),
                          segments: SourceSegments(all), to: parent)
        for (position, segments) in lineSegments.enumerated() {
            if let lower = segments.first?.lowerBound, let upper = segments.last?.upperBound {
                var bytes: [UInt8] = []
                for segment in segments { appendRepaired(segment, to: &bytes) }
                append(.text(String(decoding: bytes, as: UTF8.self)), range: SourceRange(lower, upper),
                       segments: SourceSegments(segments), to: node)
            }
            if position + 1 < lineSegments.count {
                let line = lines[first + position]
                append(.softBreak, range: SourceRange(line.contentRange.upperBound, line.range.upperBound), to: node)
            }
        }
    }
}
