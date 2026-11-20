import SetzerSyntax

extension InlineParser {
    struct LinkTarget {
        let end: Int
        let destination: Range<Int>
        let title: Range<Int>?
    }

    func skipWhitespace(_ offset: Int) -> Int {
        var i = offset
        while i < bytes.count && HTMLSyntax.whitespace(bytes[i]) { i += 1 }
        return i
    }

    func inlineTarget(at start: Int) -> LinkTarget? {
        guard start < bytes.count && bytes[start] == 40 else { return nil }
        var i = skipWhitespace(start + 1)
        let destination: Range<Int>
        if i < bytes.count && bytes[i] == 60 {
            i += 1
            let lower = i
            while i < bytes.count && bytes[i] != 62 {
                if bytes[i] == 60 || bytes[i] == 10 { return nil }
                if bytes[i] == 92 && i + 1 < bytes.count && InlineDecoding.punctuation(bytes[i + 1]) { i += 2 }
                else { i += 1 }
            }
            guard i < bytes.count else { return nil }
            destination = lower..<i
            i += 1
        } else {
            let lower = i
            var depth = 0
            while i < bytes.count && !HTMLSyntax.whitespace(bytes[i]) {
                if (bytes[i] != 0 && bytes[i] < 32) || bytes[i] == 127 { return nil }
                if bytes[i] == 92 && i + 1 < bytes.count && InlineDecoding.punctuation(bytes[i + 1]) { i += 2; continue }
                if bytes[i] == 40 { depth += 1; if depth > 32 { return nil } }
                if bytes[i] == 41 { if depth == 0 { break }; depth -= 1 }
                i += 1
            }
            guard depth == 0 else { return nil }
            destination = lower..<i
        }
        let afterDestination = i
        i = skipWhitespace(i)
        if i < bytes.count && bytes[i] == 41 { return LinkTarget(end: i + 1, destination: destination, title: nil) }
        guard i > afterDestination, i < bytes.count, [UInt8(34), 39, 40].contains(bytes[i]) else { return nil }
        let opening = bytes[i]
        let closing: UInt8 = opening == 40 ? 41 : opening
        i += 1
        let titleStart = i
        while i < bytes.count && bytes[i] != closing {
            if opening == 40 && bytes[i] == 40 { return nil }
            if bytes[i] == 92 && i + 1 < bytes.count && InlineDecoding.punctuation(bytes[i + 1]) { i += 2 }
            else { i += 1 }
        }
        guard i < bytes.count else { return nil }
        let title = titleStart..<i
        i = skipWhitespace(i + 1)
        guard i < bytes.count && bytes[i] == 41 else { return nil }
        return LinkTarget(end: i + 1, destination: destination, title: title)
    }

    /// At most 999 Unicode scalars, with no unescaped brackets. A byte limit
    /// bounds failed scans too, including malformed UTF-8 input.
    func referenceLabel(at start: Int) -> (end: Int, content: Range<Int>)? {
        guard start < bytes.count && bytes[start] == 91 else { return nil }
        var i = start + 1
        while i < bytes.count && i - start <= 3997 {
            if bytes[i] == 93 {
                let content = (start + 1)..<i
                guard String(decoding: bytes[content], as: UTF8.self).unicodeScalars.count <= 999 else { return nil }
                return (i + 1, content)
            }
            if bytes[i] == 91 { return nil }
            if bytes[i] == 92 && i + 1 < bytes.count && InlineDecoding.punctuation(bytes[i + 1]) { i += 2 }
            else { i += 1 }
        }
        return nil
    }

    mutating func closeBracket() {
        let close = cursor
        cursor += 1
        guard let bracket = brackets.popLast() else { text(close, cursor); return }
        customOpeners.removeAll { $0.bracketDepth > brackets.count }
        guard bracket.active else { text(close, cursor); return }
        let opener = bracket.item
        let labelStart = items[opener].end
        var destination: String?
        var title: String?
        var target: LinkTarget?
        var referenceRange: Range<Int>?
        if let match = inlineTarget(at: cursor) {
            target = match
            destination = InlineDecoding.decode(bytes[match.destination])
            title = match.title.map { InlineDecoding.decode(bytes[$0]) }
            cursor = match.end
        } else if !references.isEmpty {
            let explicit = referenceLabel(at: cursor)
            let label: Range<Int>
            if let explicit, !explicit.content.isEmpty { label = explicit.content }
            else {
                guard !bracket.bracketAfter, close - labelStart <= 3996 else { text(close, cursor); return }
                label = labelStart..<close
            }
            let raw = InlineDecoding.decode(bytes[label], escapes: false, entities: false)
            if raw.unicodeScalars.count <= 999, let ref = references[InlineDecoding.label(raw)] {
                destination = ref.destination
                title = ref.title
                if let explicit { referenceRange = explicit.content; cursor = explicit.end }
            }
        }
        guard let destination else { cursor = close + 1; text(close, cursor); return }
        // Resolve emphasis inside the label before it becomes a protected node.
        emphasis(bottom: bracket.bottom)
        let data: NodeData = bracket.image ? .image(destination: destination, title: title) : .link(destination: destination, title: title)
        let item = wrap(data, opener: opener, closer: nil, start: items[opener].start, end: cursor)
        token(item, "core.link.open", items[opener].start, labelStart)
        token(item, "core.link.label", labelStart, close)
        token(item, "core.link.close", close, close + 1)
        if let target {
            token(item, "core.link.marker", close + 1, close + 2)
            token(item, "core.link.marker", cursor - 1, cursor)
            if target.destination.lowerBound > 0 && bytes[target.destination.lowerBound - 1] == 60 {
                token(item, "core.link.marker", target.destination.lowerBound - 1, target.destination.lowerBound)
                token(item, "core.link.marker", target.destination.upperBound, target.destination.upperBound + 1)
            }
            token(item, "core.link.destination", target.destination.lowerBound, target.destination.upperBound)
            if let title = target.title {
                token(item, "core.link.title", title.lowerBound, title.upperBound)
                token(item, "core.link.marker", title.lowerBound - 1, title.lowerBound)
                token(item, "core.link.marker", title.upperBound, title.upperBound + 1)
            }
        }
        if let referenceRange {
            token(item, "core.link.reference", referenceRange.lowerBound, referenceRange.upperBound)
            token(item, "core.link.marker", referenceRange.lowerBound - 1, referenceRange.lowerBound)
            token(item, "core.link.marker", referenceRange.upperBound, referenceRange.upperBound + 1)
        }
        unlink(opener)
        if !bracket.image { deactivateLinkOpeners() }
    }

    private mutating func deactivateLinkOpeners() {
        // Each existing link bracket is deactivated at most once. Images can
        // contain links as alt content, including an autolink.
        for index in brackets.indices.reversed() {
            if !brackets[index].image {
                if !brackets[index].active { break }
                brackets[index].active = false
            }
        }
    }

    mutating func angle() -> Bool {
        let start = cursor
        if let end = autolinkEnd(at: start) {
            let content = bytes[(start + 1)..<(end - 1)]
            let raw = InlineDecoding.decode(content, escapes: false, entities: false)
            let isEmail = !content.contains(58)
            let item = append(.link(destination: (isEmail ? "mailto:" : "") + raw, title: nil), start, end)
            let child = items.count
            items.append(Item(data: .text(raw), start: start + 1, end: end - 1))
            items[item].firstChild = child
            token(item, "core.link.open", start, start + 1)
            token(item, "core.link.destination", start + 1, end - 1)
            token(item, "core.link.close", end - 1, end)
            deactivateLinkOpeners()
            cursor = end
            return true
        }
        if let end = htmlEnd(at: start) {
            let literal = InlineDecoding.decode(bytes[start..<end], escapes: false, entities: false)
            let item = append(.htmlInline(literal), start, end)
            token(item, "core.html", start, end)
            cursor = end
            return true
        }
        return false
    }

    func autolinkEnd(at start: Int) -> Int? {
        var i = start + 1
        guard i < bytes.count else { return nil }
        if HTMLSyntax.letter(bytes[i]) {
            i += 1
            while i < bytes.count && (HTMLSyntax.letter(bytes[i]) || HTMLSyntax.digit(bytes[i]) || [UInt8(43), 46, 45].contains(bytes[i])) { i += 1 }
            if (2...32).contains(i - start - 1), i < bytes.count, bytes[i] == 58 {
                i += 1
                while i < bytes.count && (bytes[i] > 32 || bytes[i] == 0) && bytes[i] != 60 && bytes[i] != 62 { i += 1 }
                if i < bytes.count && bytes[i] == 62 { return i + 1 }
            }
        }
        i = start + 1
        let localStart = i
        while i < bytes.count && (HTMLSyntax.letter(bytes[i]) || HTMLSyntax.digit(bytes[i]) || ".!#$%&'*+/=?^_`{|}~-".utf8.contains(bytes[i])) { i += 1 }
        guard i > localStart, i < bytes.count, bytes[i] == 64 else { return nil }
        i += 1
        while i < bytes.count {
            let labelStart = i
            while i < bytes.count && (HTMLSyntax.letter(bytes[i]) || HTMLSyntax.digit(bytes[i]) || bytes[i] == 45) { i += 1 }
            guard i > labelStart, i - labelStart <= 63, bytes[labelStart] != 45, bytes[i - 1] != 45 else { return nil }
            if i < bytes.count && bytes[i] == 62 { return i + 1 }
            guard i < bytes.count && bytes[i] == 46 else { return nil }
            i += 1
        }
        return nil
    }

    mutating func htmlEnd(at start: Int) -> Int? {
        let end = bytes.count
        for (prefix, suffix, key) in [("<!--", "-->", "comment"), ("<?", "?>", "pi"), ("<![CDATA[", "]]>", "cdata")] {
            if HTMLSyntax.matches(prefix, in: bytes, at: start, end: end) {
                guard !failedHTML.contains(key) else { return nil }
                var i = start + prefix.utf8.count
                if key == "comment" {
                    if i < end && bytes[i] == 62 { return i + 1 }
                    if i + 1 < end && bytes[i] == 45 && bytes[i + 1] == 62 { return i + 2 }
                }
                while i < end {
                    if HTMLSyntax.matches(suffix, in: bytes, at: i, end: end) { return i + suffix.utf8.count }
                    i += 1
                }
                failedHTML.insert(key)
                return nil
            }
        }
        if start + 2 < end && bytes[start + 1] == 33 && HTMLSyntax.letter(bytes[start + 2]) {
            guard !failedHTML.contains("declaration") else { return nil }
            var i = start + 3
            while i < end && bytes[i] != 62 { i += 1 }
            if i < end { return i + 1 }
            failedHTML.insert("declaration")
            return nil
        }
        return HTMLSyntax.completeTag(in: bytes, at: start, end: end)?.end
    }
}
