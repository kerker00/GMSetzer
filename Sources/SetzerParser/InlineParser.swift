import SetzerSyntax

/// A logical leaf stream over the original block projections. Only line endings
/// are rewritten; each piece maps back to exact source bytes, including CRLF.
internal struct InlineInput: Sendable {
    struct Piece: Sendable { let start: Int; let end: Int; let source: SourceRange }
    var bytes: [UInt8] = []
    var pieces: [Piece] = []

    init(_ document: Document, children: [Int]) {
        var byteCount = 0
        var pieceCount = 0
        for child in children {
            let node = document.nodes[child]
            if case .softBreak = node.data { byteCount += 1; pieceCount += 1; continue }
            switch node.segments {
            case .none: byteCount += node.range.count; pieceCount += 1
            case .one(let range): byteCount += range.count; pieceCount += 1
            case .many(let ranges):
                for range in ranges { byteCount += range.count }
                pieceCount += ranges.count
            }
        }
        bytes.reserveCapacity(byteCount)
        pieces.reserveCapacity(pieceCount)
        for child in children {
            let node = document.nodes[child]
            if case .softBreak = node.data {
                pieces.append(Piece(start: bytes.count, end: bytes.count + 1, source: node.range))
                bytes.append(10)
            } else {
                switch node.segments {
                case .none: append(node.range, source: document.source)
                case .one(let range): append(range, source: document.source)
                case .many(let ranges): for range in ranges { append(range, source: document.source) }
                }
            }
        }
    }

    private mutating func append(_ range: SourceRange, source: [UInt8]) {
        guard !range.isEmpty else { return }
        pieces.append(Piece(start: bytes.count, end: bytes.count + range.count, source: range))
        bytes.append(contentsOf: source[range.lowerBound..<range.upperBound])
    }

    /// The common one-piece case creates no temporary segment array.
    func mapped(_ start: Int, _ end: Int) -> (range: SourceRange, segments: SourceSegments) {
        let p = pieces[piece(at: start)]
        if end <= p.end {
            let range = SourceRange(p.source.lowerBound + start - p.start,
                                    p.source.upperBound - max(0, p.end - end))
            return (range, .one(range))
        }
        let ranges = ranges(start, end)
        return (SourceRange(ranges.first!.lowerBound, ranges.last!.upperBound), SourceSegments(ranges))
    }

    func slice(_ range: SourceRange) -> InlineInput {
        var result = InlineInput()
        result.bytes = Array(bytes[range.lowerBound..<range.upperBound])
        for piece in pieces where piece.end > range.lowerBound && piece.start < range.upperBound {
            let lower = max(range.lowerBound, piece.start)
            let upper = min(range.upperBound, piece.end)
            let source = SourceRange(piece.source.lowerBound + lower - piece.start,
                                     piece.source.upperBound - (piece.end - upper))
            result.pieces.append(Piece(start: lower - range.lowerBound, end: upper - range.lowerBound, source: source))
        }
        return result
    }

    init() {}

    func piece(at offset: Int) -> Int {
        var low = 0
        var high = pieces.count
        while low < high {
            let mid = (low + high) / 2
            if pieces[mid].end <= offset { low = mid + 1 } else { high = mid }
        }
        return min(low, pieces.count - 1)
    }

    func ranges(_ start: Int, _ end: Int) -> [SourceRange] {
        guard !pieces.isEmpty else { return [] }
        if start == end {
            let index = piece(at: start)
            let p = pieces[index]
            let offset = start == p.end ? p.source.upperBound : p.source.lowerBound + start - p.start
            return [SourceRange(offset, offset)]
        }
        var result: [SourceRange] = []
        var index = piece(at: start)
        while index < pieces.count, pieces[index].start < end {
            let p = pieces[index]
            let lower = p.source.lowerBound + max(0, start - p.start)
            let upper = p.source.upperBound - max(0, p.end - end)
            if let last = result.last, last.upperBound == lower {
                result[result.count - 1] = SourceRange(last.lowerBound, upper)
            } else { result.append(SourceRange(lower, upper)) }
            index += 1
        }
        return result
    }

    func range(_ start: Int, _ end: Int) -> SourceRange {
        let segments = ranges(start, end)
        return SourceRange(segments.first!.lowerBound, segments.last!.upperBound)
    }
}

/// Core delimiter-stack algorithm follows CommonMark's parsing strategy and
/// cmark's openers-bottom optimization (BSD-2; see NOTICE). Nodes and stack
/// entries use indices, with O(1) unlink/splice and no recursive parsing.
internal struct InlineParser {
    struct Item {
        var data: NodeData
        var start: Int
        var end: Int
        var previous: Int?
        var next: Int?
        var firstChild: Int?
        var tokens: [(String, Int, Int)] = []
        var fallback: String?
    }
    struct Delimiter {
        let item: Int
        let marker: UInt8
        let originalWidth: Int
        let canOpen: Bool
        let canClose: Bool
        var previous: Int?
        var next: Int?
        var live = true
    }
    struct Bracket {
        let item: Int
        let image: Bool
        let bottom: Int
        var active: Bool
        var bracketAfter = false
    }
    struct Reference {
        let sourceOffset: Int
        let destination: String
        let title: String?
    }

    var input: InlineInput
    let references: [ReferenceLabel: Reference]
    let collectSyntax: Bool
    let source: [UInt8]
    let rules: [UInt8: [ActiveInlineRule]]
    let triggers: ByteSet
    let hasCustomRules: Bool
    let maximumDepth: Int
    let depth: Int
    /// GFM strikethrough (`~`) and extended www/URL autolinks; set them with
    /// `enableGFM`, which also updates the text-run stop bytes.
    private(set) var strikethrough = false
    private(set) var autolink = false
    /// Bytes that end a plain text run: core specials and custom triggers.
    private var baseStops = ByteSet()
    /// `baseStops` plus the GFM trigger bytes in use.
    private var textStops = ByteSet()
    var diagnostics: [ParseDiagnostic] = []
    var customOpeners: [CustomOpener] = []
    var items: [Item] = []
    var first: Int?
    var last: Int?
    var delimiters: [Delimiter] = []
    var lastDelimiter: Int?
    var brackets: [Bracket] = []
    var cursor = 0
    var backticks: [Int: [Int]] = [:]
    var singleBackticks: [Int] = []
    var singleBacktickNext = 0
    var backtickNext: [Int: Int] = [:]
    var failedHTML: Set<String> = []
    var customRunEnd = 0
    var customRunMarker: UInt8 = 0
    var bytes: [UInt8]

    init(input: InlineInput, references: [ReferenceLabel: Reference], collectSyntax: Bool = false,
         source: [UInt8] = [], rules: [UInt8: [ActiveInlineRule]] = [:], triggers: ByteSet = ByteSet(), maximumDepth: Int = 16, depth: Int = 0) {
        self.input = input
        self.bytes = input.bytes
        self.items.reserveCapacity(min(4096, input.bytes.count / 4 + 1))
        self.references = references
        self.collectSyntax = collectSyntax
        self.source = source
        self.rules = rules
        self.triggers = triggers
        self.hasCustomRules = !rules.isEmpty
        self.maximumDepth = maximumDepth
        self.depth = depth
        for byte: UInt8 in [92, 38, 96, 42, 95, 91, 93, 33, 60, 10] { baseStops.insert(byte) }
        if !rules.isEmpty { for byte in 0...255 where triggers.contains(UInt8(byte)) { baseStops.insert(UInt8(byte)) } }
        textStops = baseStops
        indexBackticks()
    }

    mutating func enableGFM(strikethrough: Bool, autolink: Bool) {
        self.strikethrough = strikethrough
        self.autolink = autolink
        textStops = baseStops
        if strikethrough { textStops.insert(126) }
        if autolink { textStops.insert(119); textStops.insert(58) }
    }

    /// Reuse per-leaf controller storage inside this parse. Result nodes retain
    /// their own value storage; no scratch handles survive into the next leaf.
    mutating func reset(to input: InlineInput) {
        self.input = input
        self.bytes = input.bytes
        items.removeAll(keepingCapacity: true)
        delimiters.removeAll(keepingCapacity: true)
        brackets.removeAll(keepingCapacity: true)
        customOpeners.removeAll(keepingCapacity: true)
        diagnostics.removeAll(keepingCapacity: true)
        backticks.removeAll(keepingCapacity: true)
        singleBackticks.removeAll(keepingCapacity: true)
        singleBacktickNext = 0
        backtickNext.removeAll(keepingCapacity: true)
        failedHTML.removeAll(keepingCapacity: true)
        first = nil; last = nil; lastDelimiter = nil
        cursor = 0; customRunEnd = 0; customRunMarker = 0
        items.reserveCapacity(min(4096, bytes.count / 4 + 1))
        indexBackticks()
    }

    private mutating func indexBackticks() {
        // Index every backtick run once, including potential code content. Failed
        // openers never rescan the leaf; each cursor skips already consumed runs.
        var i = 0
        while i < bytes.count {
            if bytes[i] == 96 {
                let start = i
                while i < bytes.count && bytes[i] == 96 { i += 1 }
                if i - start == 1 { singleBackticks.append(start) }
                else { backticks[i - start, default: []].append(start) }
            } else { i += 1 }
        }
    }

    @discardableResult
    mutating func append(_ data: NodeData, _ start: Int, _ end: Int) -> Int {
        let index = items.count
        items.append(Item(data: data, start: start, end: end, previous: last))
        if let last { items[last].next = index } else { first = index }
        last = index
        return index
    }

    mutating func text(_ start: Int, _ end: Int, literal: String? = nil) {
        guard end > start else { return }
        let text: String
        if let literal { text = literal }
        else if bytes[start..<end].contains(0) {
            text = InlineDecoding.decode(Array(bytes[start..<end]), escapes: false, entities: false)
        } else { text = String(decoding: bytes[start..<end], as: UTF8.self) }
        append(.text(text), start, end)
    }

    mutating func token(_ item: Int, _ role: String, _ start: Int, _ end: Int) {
        if collectSyntax { items[item].tokens.append((role, start, end)) }
    }

    mutating func unlink(_ index: Int) {
        let item = items[index]
        if let previous = item.previous { items[previous].next = item.next } else { first = item.next }
        if let next = item.next { items[next].previous = item.previous } else { last = item.previous }
    }

    /// Wrap siblings strictly between two delimiter nodes; the endpoints remain
    /// in place until the caller removes any exhausted delimiter text.
    mutating func wrap(_ data: NodeData, opener: Int, closer: Int?, start: Int, end: Int) -> Int {
        let child = items[opener].next
        let tail = closer.flatMap { items[$0].previous } ?? last
        let index = items.count
        items.append(Item(data: data, start: start, end: end, previous: opener, next: closer,
                          firstChild: child == closer ? nil : child))
        if child != closer {
            if let child { items[child].previous = nil }
            if let tail { items[tail].next = nil }
        }
        items[opener].next = index
        if let closer { items[closer].previous = index } else { last = index }
        return index
    }

    func scalar(before offset: Int) -> Unicode.Scalar? {
        guard offset > 0 else { return nil }
        if bytes[offset - 1] < 128 { return Unicode.Scalar(bytes[offset - 1]) }
        var start = offset - 1
        while start > 0 && bytes[start] & 0xC0 == 0x80 { start -= 1 }
        return String(decoding: bytes[start..<offset], as: UTF8.self).unicodeScalars.last
    }
    func scalar(at offset: Int) -> Unicode.Scalar? {
        guard offset < bytes.count else { return nil }
        if bytes[offset] < 128 { return Unicode.Scalar(bytes[offset]) }
        var end = offset + 1
        while end < bytes.count && bytes[end] & 0xC0 == 0x80 { end += 1 }
        return String(decoding: bytes[offset..<end], as: UTF8.self).unicodeScalars.first
    }
    func whitespace(_ scalar: Unicode.Scalar?) -> Bool {
        guard let scalar else { return true }
        return InlineDecoding.whitespace(scalar)
    }
    func punctuation(_ scalar: Unicode.Scalar?) -> Bool {
        guard let scalar else { return false }
        if scalar.value < 128 { return InlineDecoding.punctuation(UInt8(scalar.value)) }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation,
             .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol: return true
        default: return false
        }
    }

    mutating func delimiterRun() {
        let start = cursor
        let marker = bytes[cursor]
        while cursor < bytes.count && bytes[cursor] == marker { cursor += 1 }
        let before = scalar(before: start)
        let after = scalar(at: cursor)
        let left = !whitespace(after) && (!punctuation(after) || whitespace(before) || punctuation(before))
        let right = !whitespace(before) && (!punctuation(before) || whitespace(after) || punctuation(after))
        let canOpen = left && (marker != 95 || !right || punctuation(before))
        let canClose = right && (marker != 95 || !left || punctuation(after))
        let item = append(.text(""), start, cursor)
        if canOpen || canClose {
            let index = delimiters.count
            delimiters.append(Delimiter(item: item, marker: marker, originalWidth: cursor - start,
                                        canOpen: canOpen, canClose: canClose, previous: lastDelimiter))
            if let lastDelimiter { delimiters[lastDelimiter].next = index }
            lastDelimiter = index
        }
    }

    mutating func removeDelimiter(_ index: Int) {
        let d = delimiters[index]
        if let previous = d.previous { delimiters[previous].next = d.next }
        if let next = d.next { delimiters[next].previous = d.previous }
        if lastDelimiter == index { lastDelimiter = d.previous }
        delimiters[index].live = false
    }

    mutating func emphasis(bottom: Int = 0) {
        // Separate lower bounds for each marker, closer flanking, and residue.
        // Entries 12...14 are GFM strikethrough, keyed by width like cmark-gfm.
        var bottoms = [Int](repeating: bottom - 1, count: 15)
        var current: Int? = lastDelimiter
        var firstRelevant: Int?
        while let i = current, i >= bottom { firstRelevant = i; current = delimiters[i].previous }
        current = firstRelevant
        while let closer = current {
            let c = delimiters[closer]
            if !c.canClose { current = c.next; continue }
            let key = c.marker == 126 ? 12 + c.originalWidth % 3
                : (c.marker == 42 ? 0 : 6) + (c.canOpen ? 3 : 0) + c.originalWidth % 3
            var candidate = c.previous
            var found: Int?
            while let opener = candidate, opener >= bottom, opener > bottoms[key] {
                let o = delimiters[opener]
                if o.marker == c.marker && o.canOpen &&
                    (!(c.canOpen || o.canClose) || (o.originalWidth + c.originalWidth) % 3 != 0 ||
                     (o.originalWidth % 3 == 0 && c.originalWidth % 3 == 0)) {
                    found = opener; break
                }
                candidate = o.previous
            }
            guard let opener = found else {
                bottoms[key] = c.previous ?? (bottom - 1)
                current = c.next
                if !c.canOpen { removeDelimiter(closer) }
                continue
            }
            if c.marker == 126 {
                strikethrough(opener: opener, closer: closer)
                current = c.next
                continue
            }
            let openItem = delimiters[opener].item
            let closeItem = c.item
            let width = min(items[openItem].end - items[openItem].start,
                            items[closeItem].end - items[closeItem].start) >= 2 ? 2 : 1
            let start = items[openItem].end - width
            let end = items[closeItem].start + width
            let container = wrap(width == 2 ? .strong : .emphasis, opener: openItem, closer: closeItem, start: start, end: end)
            token(container, "core.emphasis.open", start, start + width)
            token(container, "core.emphasis.close", end - width, end)
            items[openItem].end -= width
            items[closeItem].start += width
            // Materialize residual delimiter spelling once, at emission. Rebuilding
            // a shrinking long run after every pair would be quadratic.
            items[openItem].data = .text("")
            items[closeItem].data = .text("")
            var between = delimiters[closer].previous
            while let i = between, i != opener { between = delimiters[i].previous; removeDelimiter(i) }
            if items[openItem].start == items[openItem].end { unlink(openItem); removeDelimiter(opener) }
            if items[closeItem].start == items[closeItem].end {
                current = delimiters[closer].next
                unlink(closeItem); removeDelimiter(closer)
            }
        }
        while let i = lastDelimiter, i >= bottom { removeDelimiter(i) }
    }

    /// GFM strikethrough (ported from cmark-gfm `strikethrough.c`, BSD-2; see NOTICE):
    /// equal one- or two-tilde runs wrap their content; unequal runs stay
    /// literal. Delimiters between the pair are discarded either way.
    mutating func strikethrough(opener: Int, closer: Int) {
        var between = delimiters[closer].previous
        while let i = between, i != opener { between = delimiters[i].previous; removeDelimiter(i) }
        let openItem = delimiters[opener].item, closeItem = delimiters[closer].item
        if delimiters[opener].originalWidth == delimiters[closer].originalWidth {
            let start = items[openItem].start, end = items[closeItem].end
            let container = wrap(.strikethrough, opener: openItem, closer: closeItem, start: start, end: end)
            token(container, "gfm.strikethrough.open", start, items[openItem].end)
            token(container, "gfm.strikethrough.close", items[closeItem].start, end)
            unlink(openItem)
            unlink(closeItem)
        }
        removeDelimiter(opener)
        removeDelimiter(closer)
    }

    /// cmark-gfm scans at most 100 tildes per run and pushes only runs of one
    /// or two, flanked with Unicode P-category punctuation (no symbols).
    mutating func tildeRun() {
        let start = cursor
        while cursor < bytes.count && bytes[cursor] == 126 && cursor - start < 100 { cursor += 1 }
        let before = scalar(before: start), after = scalar(at: cursor)
        func space(_ scalar: Unicode.Scalar?) -> Bool { scalar.map(Self.gfmSpace) ?? true }
        func punct(_ scalar: Unicode.Scalar?) -> Bool { scalar.map(Self.gfmPunctuation) ?? false }
        let left = !space(after) && (!punct(after) || space(before) || punct(before))
        let right = !space(before) && (!punct(before) || space(after) || punct(after))
        let item = append(.text(""), start, cursor)
        let width = cursor - start
        if (left || right) && width <= 2 {
            let index = delimiters.count
            delimiters.append(Delimiter(item: item, marker: 126, originalWidth: width,
                                        canOpen: left, canClose: right, previous: lastDelimiter))
            if let lastDelimiter { delimiters[lastDelimiter].next = index }
            lastDelimiter = index
        }
    }

    /// `cmark_utf8proc_is_space`.
    static func gfmSpace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 9, 10, 12, 13, 32, 160, 5760, 8192...8202, 8239, 8287, 12288: true
        default: false
        }
    }

    /// `cmark_utf8proc_is_punctuation`: ASCII punctuation and Unicode P*.
    static func gfmPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.value < 128 { return InlineDecoding.punctuation(UInt8(scalar.value)) }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation: return true
        default: return false
        }
    }

    mutating func parse() {
        while cursor < bytes.count {
            let start = cursor
            // Escapes, code and link structure are core-protected entry points.
            // Custom triggers are resolved by this controller before ordinary text
            // and core emphasis, never from inside a consumed destination/code node.
            if hasCustomRules, triggers.contains(bytes[cursor]), ![UInt8(92), 96, 91, 93, 60].contains(bytes[cursor]),
               !(bytes[cursor] == 33 && cursor + 1 < bytes.count && bytes[cursor + 1] == 91),
               customMatch() { continue }
            switch bytes[cursor] {
            case 92:
                cursor += 1
                if cursor < bytes.count && InlineDecoding.punctuation(bytes[cursor]) {
                    cursor += 1
                    let item = append(.text(String(decoding: bytes[(start + 1)..<cursor], as: UTF8.self)), start, cursor)
                    token(item, "core.escape", start, cursor)
                } else if cursor < bytes.count && bytes[cursor] == 10 {
                    cursor += 1
                    let item = append(.hardBreak, start, cursor)
                    token(item, "core.break", start, cursor)
                } else { text(start, cursor) }
            case 38:
                if let match = InlineDecoding.entity(bytes, at: cursor) {
                    let item = append(.text(match.text), cursor, match.end)
                    token(item, "core.entity", cursor, match.end)
                    cursor = match.end
                } else { cursor += 1; text(start, cursor) }
            case 96: codeSpan()
            case 42, 95: delimiterRun()
            case 126 where strikethrough: tildeRun()
            case 91:
                if !brackets.isEmpty { brackets[brackets.count - 1].bracketAfter = true }
                let item = append(.text("["), cursor, cursor + 1)
                brackets.append(Bracket(item: item, image: false, bottom: delimiters.count, active: true))
                cursor += 1
            case 33 where cursor + 1 < bytes.count && bytes[cursor + 1] == 91:
                if !brackets.isEmpty { brackets[brackets.count - 1].bracketAfter = true }
                let item = append(.text("!["), cursor, cursor + 2)
                brackets.append(Bracket(item: item, image: true, bottom: delimiters.count, active: true))
                cursor += 2
            case 93: closeBracket()
            case 60:
                if !angle() { cursor += 1; text(start, cursor) }
            case 10:
                let hard = cursor >= 2 && bytes[cursor - 1] == 32 && bytes[cursor - 2] == 32
                var markerStart = cursor
                if hard {
                    while markerStart > 0 && (bytes[markerStart - 1] == 32 || bytes[markerStart - 1] == 9) { markerStart -= 1 }
                }
                cursor += 1
                let item = append(hard ? .hardBreak : .softBreak, markerStart, cursor)
                if hard { token(item, "core.break", markerStart, cursor) }
            default:
                if autolink, brackets.isEmpty, autolinkCandidate(cursor), extendedAutolink() { continue }
                cursor += 1
                if strikethrough || autolink {
                    while cursor < bytes.count {
                        let byte = bytes[cursor]
                        if textStops.contains(byte) {
                            // 'w' and ':' end the run only where an autolink can start.
                            guard (byte == 119 || byte == 58) && !baseStops.contains(byte)
                                    && !(brackets.isEmpty && autolinkCandidate(cursor)) else { break }
                        }
                        cursor += 1
                    }
                } else {
                    // CommonMark keeps the original single-dispatch loop.
                    while cursor < bytes.count && (!hasCustomRules || !triggers.contains(bytes[cursor])) && !Self.special(bytes[cursor]) { cursor += 1 }
                }
                var end = cursor
                if cursor < bytes.count && bytes[cursor] == 10 {
                    while end > start && (bytes[end - 1] == 32 || bytes[end - 1] == 9) { end -= 1 }
                }
                text(start, end)
            }
        }
        emphasis()
        if autolink && depth == 0 && bytes.contains(64) { emailAutolinks() }
    }

    @inline(__always)
    private static func special(_ byte: UInt8) -> Bool {
        switch byte {
        case 92, 38, 96, 42, 95, 91, 93, 33, 60, 10: true
        default: false
        }
    }

    mutating func codeSpan() {
        let start = cursor
        while cursor < bytes.count && bytes[cursor] == 96 { cursor += 1 }
        let width = cursor - start
        let positions = width == 1 ? singleBackticks : backticks[width] ?? []
        var next = width == 1 ? singleBacktickNext : backtickNext[width] ?? 0
        while next < positions.count && positions[next] < cursor { next += 1 }
        if width == 1 { singleBacktickNext = next } else { backtickNext[width] = next }
        guard next < positions.count else { text(start, cursor); return }
        let close = positions[next]
        let raw = bytes[cursor..<close]
        let literal: String
        if !raw.contains(10) {
            let trim = raw.first == 32 && raw.last == 32 && raw.contains(where: { $0 != 32 })
            let content = trim ? raw.dropFirst().dropLast() : raw
            literal = InlineDecoding.decode(content, escapes: false, entities: false)
        } else {
            var normalized = raw.map { $0 == 10 ? UInt8(32) : $0 }
            if normalized.first == 32 && normalized.last == 32 && normalized.contains(where: { $0 != 32 }) {
                normalized.removeLast(); normalized.removeFirst()
            }
            literal = InlineDecoding.decode(normalized, escapes: false, entities: false)
        }
        let item = append(.code(literal), start, close + width)
        token(item, "core.code.open", start, cursor)
        token(item, "core.code.content", cursor, close)
        token(item, "core.code.close", close, close + width)
        cursor = close + width
    }
}
