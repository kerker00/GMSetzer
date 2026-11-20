import GMSetzer

/// Comparison policy, deliberately narrower than cmark's historical HTML
/// normalizer: only the optional slash in generated br/hr/img tags changes.
/// Text, attributes, comments, declarations, code and original raw HTML remain
/// byte-identical. Strict fixture equality is still checked independently.
enum HTMLNormalization {
    static func normalize(_ html: String, document: Document) -> String {
        let bytes = Array(html.utf8)
        let raw = document.nodes.compactMap { node -> [UInt8]? in
            switch node.data {
            case .htmlBlock(let block): return Array(block.literal.utf8)
            case .htmlInline(let text): return Array(text.utf8)
            default: return nil
            }
        }.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
        var output: [UInt8] = []
        var cursor = 0
        var codeDepth = 0
        while cursor < bytes.count {
            if let literal = raw.first(where: { bytes[cursor...].starts(with: $0) }) {
                output.append(contentsOf: literal); cursor += literal.count; continue
            }
            guard bytes[cursor] == 60 else { output.append(bytes[cursor]); cursor += 1; continue }
            var end = cursor + 1
            var quote: UInt8?
            while end < bytes.count {
                let b = bytes[end]
                if let q = quote { if b == q { quote = nil } }
                else if b == 34 || b == 39 { quote = b }
                else if b == 62 { break }
                end += 1
            }
            guard end < bytes.count else { output.append(contentsOf: bytes[cursor...]); break }
            let tag = String(decoding: bytes[cursor...end], as: UTF8.self)
            if tag == "<pre>" || tag == "<code>" || tag.hasPrefix("<code ") { codeDepth += 1 }
            if tag == "</pre>" || tag == "</code>" { codeDepth = max(0, codeDepth - 1) }
            let void = tag == "<br />" || tag == "<hr />" || tag.hasPrefix("<img ")
            if codeDepth == 0 && void && tag.hasSuffix(" />") {
                output.append(contentsOf: bytes[cursor..<(end - 2)])
                output.append(62)
            } else { output.append(contentsOf: bytes[cursor...end]) }
            cursor = end + 1
        }
        return String(decoding: output, as: UTF8.self)
    }
}
