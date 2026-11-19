extension HTMLRenderer {
    /// Operates only on recognised HTML blocks, never on Markdown/code literals.
    /// Quoted attributes, PI/CDATA and raw-text elements retain comment-like text.
    internal static func removingHTMLComments(_ literal: String) -> String {
        let bytes = Array(literal.utf8)
        var output: [UInt8] = []
        var cursor = 0
        var removed = false
        var rawTag: String?
        func lower(_ byte: UInt8) -> UInt8 { (65...90).contains(byte) ? byte + 32 : byte }
        func matches(_ text: String, at offset: Int, folded: Bool = false) -> Bool {
            guard text.utf8.count <= bytes.count - offset else { return false }
            return text.utf8.enumerated().allSatisfy { index, byte in
                folded ? lower(bytes[offset + index]) == lower(byte) : bytes[offset + index] == byte
            }
        }
        func endOf(_ terminator: String, from start: Int) -> Int {
            var position = start
            while position < bytes.count {
                if matches(terminator, at: position) { return position + terminator.utf8.count }
                position += 1
            }
            return bytes.count
        }
        while cursor < bytes.count {
            if let name = rawTag {
                if matches("</" + name, at: cursor, folded: true) {
                    let afterName = cursor + name.utf8.count + 2
                    if afterName < bytes.count && [UInt8(32), 9, 10, 13, 62].contains(bytes[afterName]) { rawTag = nil }
                }
                if rawTag != nil { output.append(bytes[cursor]); cursor += 1; continue }
            }
            if matches("<!--", at: cursor) {
                cursor = endOf("-->", from: cursor + 4)
                removed = true
                continue
            }
            if matches("<![CDATA[", at: cursor) || matches("<?", at: cursor) {
                let end = endOf(matches("<?", at: cursor) ? "?>" : "]]>", from: cursor + 2)
                output.append(contentsOf: bytes[cursor..<end])
                cursor = end
                continue
            }
            if bytes[cursor] == 60 {
                let start = cursor
                var nameStart = cursor + 1
                let closing = nameStart < bytes.count && bytes[nameStart] == 47
                if closing { nameStart += 1 }
                var nameEnd = nameStart
                while nameEnd < bytes.count && ((65...90).contains(bytes[nameEnd]) || (97...122).contains(bytes[nameEnd]) ||
                                               (48...57).contains(bytes[nameEnd]) || bytes[nameEnd] == 45) { nameEnd += 1 }
                if nameEnd > nameStart {
                    let name = String(decoding: bytes[nameStart..<nameEnd].map(lower), as: UTF8.self)
                    cursor = nameEnd
                    var quote: UInt8?
                    while cursor < bytes.count {
                        let byte = bytes[cursor]
                        cursor += 1
                        if let current = quote {
                            if byte == current { quote = nil }
                        } else if byte == 34 || byte == 39 { quote = byte }
                        else if byte == 62 { break }
                    }
                    output.append(contentsOf: bytes[start..<cursor])
                    if !closing && ["script", "style", "textarea"].contains(name) { rawTag = name }
                    continue
                }
            }
            output.append(bytes[cursor])
            cursor += 1
        }
        if removed && output.allSatisfy({ [UInt8(32), 9, 10, 13].contains($0) }) { return "" }
        return String(decoding: output, as: UTF8.self)
    }
}
