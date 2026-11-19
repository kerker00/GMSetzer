import SetzerSyntax

/// Original byte scanners for CommonMark sections 4.6 and 6.6. No regex engine
/// or HTML runtime is required, and scans are bounded by the current line.
internal enum HTMLSyntax {
    static func letter(_ byte: UInt8) -> Bool { (65...90).contains(byte) || (97...122).contains(byte) }
    static func digit(_ byte: UInt8) -> Bool { (48...57).contains(byte) }
    static func whitespace(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 || byte == 10 || byte == 13 }
    static func folded(_ byte: UInt8) -> UInt8 { (65...90).contains(byte) ? byte + 32 : byte }
    static let rawTags: Set<String> = ["pre", "script", "style", "textarea"]
    static let blockTags: Set<String> = [
        "address", "article", "aside", "base", "basefont", "blockquote", "body", "caption", "center", "col", "colgroup",
        "dd", "details", "dialog", "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
        "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe", "legend",
        "li", "link", "main", "menu", "menuitem", "nav", "noframes", "ol", "optgroup", "option", "p", "param", "search",
        "section", "summary", "table", "tbody", "td", "tfoot", "th", "thead", "title", "tr", "track", "ul",
    ]

    static func matches(_ pattern: String, in bytes: [UInt8], at start: Int, end: Int, ignoringCase: Bool = false) -> Bool {
        guard pattern.utf8.count <= end - start else { return false }
        for (offset, byte) in pattern.utf8.enumerated() {
            if ignoringCase ? folded(bytes[start + offset]) != folded(byte) : bytes[start + offset] != byte { return false }
        }
        return true
    }

    /// End offset of a complete open/closing tag, excluding following whitespace.
    static func completeTag(in bytes: [UInt8], at start: Int, end: Int) -> (end: Int, name: String, closing: Bool)? {
        var cursor = start
        guard cursor < end, bytes[cursor] == 60 else { return nil }
        cursor += 1
        let closing = cursor < end && bytes[cursor] == 47
        if closing { cursor += 1 }
        let nameStart = cursor
        guard cursor < end, letter(bytes[cursor]) else { return nil }
        cursor += 1
        while cursor < end && (letter(bytes[cursor]) || digit(bytes[cursor]) || bytes[cursor] == 45) { cursor += 1 }
        let name = String(decoding: bytes[nameStart..<cursor].map(folded), as: UTF8.self)
        if closing {
            while cursor < end && whitespace(bytes[cursor]) { cursor += 1 }
            guard cursor < end && bytes[cursor] == 62 else { return nil }
            return (cursor + 1, name, true)
        }
        while cursor < end {
            let separator = cursor
            while cursor < end && whitespace(bytes[cursor]) { cursor += 1 }
            if cursor < end && bytes[cursor] == 62 { return (cursor + 1, name, false) }
            if cursor + 1 < end && bytes[cursor] == 47 && bytes[cursor + 1] == 62 { return (cursor + 2, name, false) }
            guard cursor > separator, cursor < end,
                  letter(bytes[cursor]) || bytes[cursor] == 95 || bytes[cursor] == 58 else { return nil }
            cursor += 1
            while cursor < end && (letter(bytes[cursor]) || digit(bytes[cursor]) || [UInt8(95), 46, 58, 45].contains(bytes[cursor])) {
                cursor += 1
            }
            let afterName = cursor
            while cursor < end && whitespace(bytes[cursor]) { cursor += 1 }
            if cursor < end && bytes[cursor] == 61 {
                cursor += 1
                while cursor < end && whitespace(bytes[cursor]) { cursor += 1 }
                guard cursor < end else { return nil }
                if bytes[cursor] == 34 || bytes[cursor] == 39 {
                    let quote = bytes[cursor]
                    cursor += 1
                    while cursor < end && bytes[cursor] != quote { cursor += 1 }
                    guard cursor < end else { return nil }
                    cursor += 1
                } else {
                    let valueStart = cursor
                    while cursor < end && !whitespace(bytes[cursor]) && ![UInt8(34), 39, 61, 60, 62, 96].contains(bytes[cursor]) {
                        cursor += 1
                    }
                    guard cursor > valueStart else { return nil }
                }
            } else {
                // Preserve the separator for the next boolean attribute.
                cursor = afterName
            }
        }
        return nil
    }
}

extension BlockParser {
    func htmlBlockStart(_ index: Int, interrupting: Bool) -> HTMLBlockKind? {
        let indent = indentation(index)
        guard indent.columns <= 3 else { return nil }
        let start = indent.offset
        let end = lines[index].contentRange.upperBound
        guard start < end && source[start] == 60 else { return nil }
        for name in HTMLSyntax.rawTags {
            let length = name.utf8.count + 1
            if HTMLSyntax.matches("<" + name, in: source, at: start, end: end, ignoringCase: true),
               start + length == end || space(source[start + length]) || source[start + length] == 62 { return .rawText }
        }
        if HTMLSyntax.matches("<!--", in: source, at: start, end: end) { return .comment }
        if HTMLSyntax.matches("<?", in: source, at: start, end: end) { return .processingInstruction }
        if HTMLSyntax.matches("<![CDATA[", in: source, at: start, end: end) { return .cdata }
        if start + 2 < end && source[start + 1] == 33 && HTMLSyntax.letter(source[start + 2]) { return .declaration }
        var cursor = start + 1
        if cursor < end && source[cursor] == 47 { cursor += 1 }
        let nameStart = cursor
        while cursor < end && (HTMLSyntax.letter(source[cursor]) || HTMLSyntax.digit(source[cursor]) || source[cursor] == 45) { cursor += 1 }
        let name = String(decoding: source[nameStart..<cursor].map(HTMLSyntax.folded), as: UTF8.self)
        if HTMLSyntax.blockTags.contains(name), cursor == end || space(source[cursor]) || source[cursor] == 62 ||
           (cursor + 1 < end && source[cursor] == 47 && source[cursor + 1] == 62) { return .blockTag }
        if !interrupting, let tag = HTMLSyntax.completeTag(in: source, at: start, end: end),
           (tag.closing || !HTMLSyntax.rawTags.contains(tag.name)), source[tag.end..<end].allSatisfy(space) { return .completeTag }
        return nil
    }

    func endsHTMLBlock(_ index: Int, kind: HTMLBlockKind) -> Bool {
        let range = lines[index].contentRange
        switch kind {
        case .blockTag, .completeTag: return false // blank lines terminate before consumption
        default: break
        }
        let patterns: [String]
        switch kind {
        case .rawText: patterns = ["</pre>", "</script>", "</style>", "</textarea>"]
        case .comment: patterns = ["-->"]
        case .processingInstruction: patterns = ["?>"]
        case .declaration: patterns = [">"]
        case .cdata: patterns = ["]]>"]
        default: patterns = []
        }
        for cursor in range.lowerBound..<range.upperBound {
            for pattern in patterns where HTMLSyntax.matches(pattern, in: source, at: cursor, end: range.upperBound, ignoringCase: kind == .rawText) {
                return true
            }
        }
        return false
    }
}
