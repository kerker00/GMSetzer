import SetzerSyntax

// GFM extended autolinks. The matching rules are ported from cmark-gfm's
// `extensions/autolink.c` as pinned in swift-cmark 08ddb528 (BSD-2-Clause,
// Copyright (c) 2014, John MacFarlane; see NOTICE) to the byte-indexed
// controller: www and URL matches run at their trigger byte, email matches
// run over decoded text after the leaf.
extension InlineParser {
    /// `cmark_isspace`: tab, LF, CR and space.
    @inline(__always)
    static func cSpace(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 || byte == 10 || byte == 13 }
    @inline(__always)
    static func cAlpha(_ byte: UInt8) -> Bool { (65...90).contains(byte) || (97...122).contains(byte) }
    @inline(__always)
    static func cAlnum(_ byte: UInt8) -> Bool { cAlpha(byte) || (48...57).contains(byte) }

    /// Cheap filter for positions where cmark-gfm's `www_match`/`url_match`
    /// could succeed, so ordinary text runs are split only there.
    @inline(__always)
    func autolinkCandidate(_ position: Int) -> Bool {
        let byte = bytes[position]
        if byte == 119 {
            guard position + 3 < bytes.count, bytes[position + 1] == 119, bytes[position + 2] == 119,
                  bytes[position + 3] == 46 else { return false }
            guard position > 0 else { return true }
            let previous = bytes[position - 1]
            // strchr("*_~(", c) also matches the terminating NUL.
            return previous == 42 || previous == 95 || previous == 126 || previous == 40 || previous == 0 || Self.cSpace(previous)
        }
        return byte == 58 && position > 0 && position + 3 < bytes.count
            && bytes[position + 1] == 47 && bytes[position + 2] == 47 && Self.cAlpha(bytes[position - 1])
    }

    /// Emits a www or URL autolink at `cursor` and advances past it.
    mutating func extendedAutolink() -> Bool {
        let start = cursor
        let size = bytes.count - start
        if bytes[start] == 119 {
            guard size >= 4 else { return false }
            var end = checkDomain(start, size, allowShort: false)
            guard end > 0 else { return false }
            while end < size && !Self.cSpace(bytes[start + end]) && bytes[start + end] != 60 { end += 1 }
            end = Self.autolinkDelimiter(bytes, start, end)
            guard end > 0 else { return false }
            let raw = String(decoding: bytes[start..<(start + end)], as: UTF8.self)
            emitAutolink(destination: "http://" + raw, start, start + end)
            return true
        }
        // ':' followed by "//"; rewind over the scheme letters already emitted.
        guard size >= 4 else { return false }
        var rewind = 0
        while rewind < start && Self.cAlpha(bytes[start - rewind - 1]) { rewind += 1 }
        guard isSafeScheme(from: start - rewind) else { return false }
        let domain = checkDomain(start + 3, size - 3, allowShort: true)
        guard domain > 0 else { return false }
        var end = 3 + domain
        while end < size && !Self.cSpace(bytes[start + end]) && bytes[start + end] != 60 { end += 1 }
        end = Self.autolinkDelimiter(bytes, start, end)
        guard end > 0 else { return false }
        unputText(rewind)
        let raw = String(decoding: bytes[(start - rewind)..<(start + end)], as: UTF8.self)
        emitAutolink(destination: raw, start - rewind, start + end)
        return true
    }

    private mutating func emitAutolink(destination: String, _ start: Int, _ end: Int) {
        let link = append(.link(destination: destination, title: nil), start, end)
        let text = items.count
        items.append(Item(data: .text(InlineDecoding.decode(Array(bytes[start..<end]), escapes: false, entities: false)),
                          start: start, end: end))
        items[link].firstChild = text
        token(link, "gfm.autolink", start, end)
        cursor = end
    }

    /// `cmark_node_unput`: drop trailing bytes from the last text items.
    private mutating func unputText(_ count: Int) {
        var remaining = count
        var current = last
        while remaining > 0, let index = current, case .text = items[index].data {
            let previous = items[index].previous
            let length = items[index].end - items[index].start
            if length <= remaining {
                remaining -= length
                unlink(index)
            } else {
                items[index].end -= remaining
                remaining = 0
                let range = items[index].start..<items[index].end
                items[index].data = .text(InlineDecoding.decode(Array(bytes[range]), escapes: false, entities: false))
            }
            current = previous
        }
    }

    /// `sd_autolink_issafe`: http://, https:// or ftp:// (any case), then a
    /// valid host character.
    private func isSafeScheme(from start: Int) -> Bool {
        let length = bytes.count - start
        for scheme in ["http://", "https://", "ftp://"] {
            let prefix = Array(scheme.utf8)
            guard length > prefix.count else { continue }
            var matches = true
            for (offset, expected) in prefix.enumerated() {
                var byte = bytes[start + offset]
                if (65...90).contains(byte) { byte += 32 }
                if byte != expected { matches = false; break }
            }
            if matches && validHostCharacter(start + prefix.count) { return true }
        }
        return false
    }

    /// `is_valid_hostchar`: a well-formed UTF-8 scalar that is neither space
    /// nor punctuation. A continuation byte is malformed on its own.
    func validHostCharacter(_ position: Int) -> Bool {
        guard position < bytes.count else { return false }
        var iterator = bytes[position..<min(bytes.count, position + 4)].makeIterator()
        var decoder = UTF8()
        guard case .scalarValue(let scalar) = decoder.decode(&iterator) else { return false }
        return !Self.gfmSpace(scalar) && !Self.gfmPunctuation(scalar)
    }

    /// `check_domain`; returns the domain length or 0. Underscores in the
    /// last two segments reject the domain unless it has more than ten dots.
    private func checkDomain(_ start: Int, _ size: Int, allowShort: Bool) -> Int {
        var periods = 0, underscoreBefore = 0, underscoreLast = 0
        var i = 1
        while i < size - 1 {
            if bytes[start + i] == 92 && i < size - 2 { i += 1 }
            let byte = bytes[start + i]
            if byte == 95 { underscoreLast += 1 }
            else if byte == 46 {
                underscoreBefore = underscoreLast
                underscoreLast = 0
                periods += 1
            } else if !validHostCharacter(start + i) && byte != 45 { break }
            i += 1
        }
        if (underscoreBefore > 0 || underscoreLast > 0) && periods <= 10 { return 0 }
        return allowShort || periods > 0 ? i : 0
    }

    /// `autolink_delim`: trim trailing punctuation, unbalanced `)` and a
    /// trailing entity-like `&name;`. `start` is the match base.
    static func autolinkDelimiter(_ bytes: [UInt8], _ start: Int, _ length: Int) -> Int {
        var end = length
        var opening = 0, closing = 0
        for i in 0..<end {
            let byte = bytes[start + i]
            if byte == 60 { end = i; break }
            if byte == 40 { opening += 1 } else if byte == 41 { closing += 1 }
        }
        while end > 0 {
            switch bytes[start + end - 1] {
            case 41:
                if closing <= opening { return end }
                closing -= 1
                end -= 1
            case 63, 33, 46, 44, 58, 42, 95, 126, 39, 34:
                end -= 1
            case 59:
                var candidate = end - 2
                while candidate > 0 && cAlpha(bytes[start + candidate]) { candidate -= 1 }
                if candidate < end - 2 && bytes[start + candidate] == 38 { end = candidate } else { end -= 1 }
            default:
                return end
            }
        }
        return end
    }

    // MARK: Email autolinks (cmark-gfm `postprocess_text`)

    /// Finds email/mailto:/xmpp: links in every run of adjacent text items
    /// outside links, as cmark-gfm does after consolidating text nodes.
    mutating func emailAutolinks() {
        // (chain head, parent item or nil for the top level)
        var chains: [(Int?, Int?)] = [(first, nil)]
        while let (head, parent) = chains.popLast() {
            var runFirst: Int?
            var runHasAt = false
            var current = head
            while true {
                let item = current
                if let item, case .text = items[item].data {
                    if runFirst == nil { runFirst = item }
                    if !runHasAt { runHasAt = containsAt(item) }
                    current = items[item].next
                    continue
                }
                // Materialise a run only when it can contain an email.
                if let start = runFirst, runHasAt {
                    var run: [Int] = []
                    var member: Int? = start
                    while let index = member, index != item { run.append(index); member = items[index].next }
                    linkEmails(in: run, parent: parent)
                }
                runFirst = nil
                runHasAt = false
                guard let item else { break }
                if case .link = items[item].data {} else if let child = items[item].firstChild { chains.append((child, item)) }
                current = items[item].next
            }
        }
    }

    /// Whether a text item's decoded text contains '@', without copying it.
    private func containsAt(_ item: Int) -> Bool {
        if case .text(let text) = items[item].data, !text.isEmpty { return text.utf8.contains(64) }
        for position in items[item].start..<items[item].end where bytes[position] == 64 { return true }
        return false
    }

    private func decodedBytes(_ item: Int) -> [UInt8] {
        if case .text(let text) = items[item].data, !text.isEmpty { return Array(text.utf8) }
        return Array(bytes[items[item].start..<items[item].end])
    }

    private mutating func linkEmails(in run: [Int], parent: Int?) {
        var data: [UInt8] = []
        var spans: [(start: Int, end: Int)] = []
        for item in run {
            let start = data.count
            data.append(contentsOf: decodedBytes(item))
            spans.append((start, data.count))
        }
        guard data.contains(64) else { return }
        let matches = Self.emailMatches(data)
        guard !matches.isEmpty else { return }
        // Right to left: a split never moves the decoded offsets before it.
        var pieces = run
        var pieceSpans = spans
        for match in matches.reversed() {
            // Split at the start first: it only inserts pieces before the end.
            guard let startPiece = splitPiece(&pieces, &pieceSpans, at: match.start),
                  let endPiece = splitPiece(&pieces, &pieceSpans, at: match.end), startPiece < endPiece else { continue }
            let firstChild = pieces[startPiece], lastChild = pieces[endPiece - 1]
            let destination = (match.mailto ? "mailto:" : "")
                + String(decoding: data[match.start..<match.end], as: UTF8.self)
            let start = items[firstChild].start, end = items[lastChild].end
            let link = items.count
            items.append(Item(data: .link(destination: destination, title: nil), start: start, end: end,
                              previous: items[firstChild].previous, next: items[lastChild].next, firstChild: firstChild))
            if let previous = items[firstChild].previous { items[previous].next = link }
            else if let parent { items[parent].firstChild = link } else { first = link }
            if let next = items[lastChild].next { items[next].previous = link } else if parent == nil { last = link }
            items[firstChild].previous = nil
            items[lastChild].next = nil
            token(link, "gfm.autolink", start, end)
            pieces.replaceSubrange(startPiece..<endPiece, with: [link])
            pieceSpans.replaceSubrange(startPiece..<endPiece, with: [(match.start, match.end)])
        }
    }

    /// Returns the index in `pieces` of the first piece starting at or after
    /// decoded offset `offset`, splitting a plain text piece when needed. A
    /// piece whose decoded text differs from its source (escape, entity) is
    /// never split; its boundary snaps to the piece start.
    private mutating func splitPiece(_ pieces: inout [Int], _ spans: inout [(start: Int, end: Int)], at offset: Int) -> Int? {
        guard let position = spans.firstIndex(where: { $0.end > offset }) else { return pieces.count }
        let span = spans[position]
        if offset <= span.start { return position }
        let item = pieces[position]
        let raw = Array(bytes[items[item].start..<items[item].end])
        guard decodedBytes(item) == raw, case .text = items[item].data else { return position }
        let cut = items[item].start + (offset - span.start)
        let right = items.count
        items.append(Item(data: .text(InlineDecoding.decode(Array(bytes[cut..<items[item].end]), escapes: false, entities: false)),
                          start: cut, end: items[item].end, previous: item, next: items[item].next))
        if let next = items[item].next { items[next].previous = right } else if last == item { last = right }
        items[item].next = right
        items[item].end = cut
        items[item].data = .text(InlineDecoding.decode(Array(bytes[items[item].start..<cut]), escapes: false, entities: false))
        pieces.insert(right, at: position + 1)
        spans[position] = (span.start, offset)
        spans.insert((offset, span.end), at: position + 1)
        return position + 1
    }

    /// Port of `postprocess_text`; returns decoded byte ranges in order.
    static func emailMatches(_ data: [UInt8]) -> [(start: Int, end: Int, mailto: Bool)] {
        var result: [(start: Int, end: Int, mailto: Bool)] = []
        var start = 0, offset = 0, remaining = data.count
        func validProtocol(_ name: String, at: Int, rewind: Int, maxRewind: Int) -> Bool {
            let protocolBytes = Array(name.utf8)
            let length = protocolBytes.count
            guard length <= maxRewind - rewind else { return false }
            guard Array(data[(at - rewind - length)..<(at - rewind)]) == protocolBytes else { return false }
            if length == maxRewind - rewind { return true }
            return !cAlnum(data[at - rewind - length - 1])
        }
        outer: while offset < remaining {
            guard let atIndex = data[(start + offset)..<(start + remaining)].firstIndex(of: 64) else { break }
            var maxRewind = atIndex - (start + offset)
            var mailto = true, xmpp = false, periods = 0
            while true {  // found_at
                let at = start + offset + maxRewind
                var rewind = 0
                while rewind < maxRewind {
                    let c = data[at - rewind - 1]
                    if cAlnum(c) || c == 46 || c == 43 || c == 45 || c == 95 { rewind += 1; continue }
                    if c == 58 {
                        if validProtocol("mailto:", at: at, rewind: rewind, maxRewind: maxRewind) { mailto = false; rewind += 1; continue }
                        if validProtocol("xmpp:", at: at, rewind: rewind, maxRewind: maxRewind) {
                            mailto = false; xmpp = true; rewind += 1; continue
                        }
                    }
                    break
                }
                if rewind == 0 { offset += maxRewind + 1; continue outer }
                var linkEnd = 1
                let limit = remaining - offset - maxRewind
                var retry = false
                while linkEnd < limit {
                    let c = data[at + linkEnd]
                    if cAlnum(c) { linkEnd += 1; continue }
                    if c == 64 {
                        offset += maxRewind + 1
                        maxRewind = linkEnd - 1
                        retry = true
                        break
                    } else if c == 46 && linkEnd < limit - 1 && cAlnum(data[at + linkEnd + 1]) {
                        periods += 1
                    } else if c == 47 && xmpp {
                    } else if c != 45 && c != 95 { break }
                    linkEnd += 1
                }
                if retry { continue }
                let lastByte = data[at + linkEnd - 1]
                if linkEnd < 2 || periods == 0 || (!cAlpha(lastByte) && lastByte != 46) {
                    offset += maxRewind + linkEnd
                    continue outer
                }
                linkEnd = autolinkDelimiter(data, at, linkEnd)
                if linkEnd == 0 { offset += maxRewind + 1; continue outer }
                result.append((at - rewind, at + linkEnd, mailto))
                start += offset + maxRewind + linkEnd
                remaining -= offset + maxRewind + linkEnd
                offset = 0
                continue outer
            }
        }
        return result
    }
}
