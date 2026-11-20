import SetzerSyntax

/// CommonMark decoding is single-pass: a decoded ampersand or backslash must
/// never introduce another entity/escape. Code and raw HTML bypass this path.
internal enum InlineDecoding {
    /// CommonMark uses Zs plus TAB/LF/FF/CR; Swift's broader whitespace
    /// property also contains VT, NEL and Unicode line/paragraph separators.
    static func whitespace(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.value < 128 { return [UInt32(9), 10, 12, 13, 32].contains(scalar.value) }
        return scalar.properties.generalCategory == .spaceSeparator
    }

    static func punctuation(_ byte: UInt8) -> Bool {
        (33...47).contains(byte) || (58...64).contains(byte) || (91...96).contains(byte) || (123...126).contains(byte)
    }

    static func entity(_ bytes: [UInt8], at start: Int) -> (end: Int, text: String)? {
        guard start + 2 < bytes.count, bytes[start] == 38 else { return nil }
        var end = start + 1
        if bytes[end] == 35 {
            end += 1
            let hex = end < bytes.count && (bytes[end] == 120 || bytes[end] == 88)
            if hex { end += 1 }
            let first = end
            var value: UInt32 = 0
            while end < bytes.count, end - first < (hex ? 6 : 7) {
                let byte = bytes[end]
                let digit: UInt32
                if (48...57).contains(byte) { digit = UInt32(byte - 48) }
                else if hex && (65...70).contains(byte) { digit = UInt32(byte - 55) }
                else if hex && (97...102).contains(byte) { digit = UInt32(byte - 87) }
                else { break }
                value = value * (hex ? 16 : 10) + digit
                end += 1
            }
            guard end > first, end < bytes.count, bytes[end] == 59 else { return nil }
            let scalar = value == 0 ? Unicode.Scalar(0xFFFD)! : Unicode.Scalar(value) ?? Unicode.Scalar(0xFFFD)!
            return (end + 1, String(scalar))
        }
        while end < bytes.count && end - start <= 32 {
            let byte = bytes[end]
            if byte == 59 {
                let name = String(decoding: bytes[(start + 1)..<end], as: UTF8.self)
                return InlineTables.entities[name].map { (end + 1, $0) }
            }
            guard HTMLSyntax.letter(byte) || HTMLSyntax.digit(byte) else { return nil }
            end += 1
        }
        return nil
    }

    static func decode(_ bytes: ArraySlice<UInt8>, escapes: Bool = true, entities: Bool = true) -> String {
        if !bytes.contains(0) && (!escapes || !bytes.contains(92)) && (!entities || !bytes.contains(38)) {
            return String(decoding: bytes, as: UTF8.self)
        }
        return decode(Array(bytes), escapes: escapes, entities: entities)
    }

    static func decode(_ text: String, escapes: Bool = true, entities: Bool = true) -> String {
        if !text.utf8.contains(0) && (!escapes || !text.utf8.contains(92)) && (!entities || !text.utf8.contains(38)) { return text }
        return decode(Array(text.utf8), escapes: escapes, entities: entities)
    }

    static func decode(_ bytes: [UInt8], escapes: Bool = true, entities: Bool = true) -> String {
        if !bytes.contains(0) && (!escapes || !bytes.contains(92)) && (!entities || !bytes.contains(38)) {
            return String(decoding: bytes, as: UTF8.self)
        }
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var cursor = 0
        while cursor < bytes.count {
            let byte = bytes[cursor]
            if escapes && byte == 92 && cursor + 1 < bytes.count && punctuation(bytes[cursor + 1]) {
                output.append(bytes[cursor + 1]); cursor += 2
            } else if entities && byte == 38, let match = entity(bytes, at: cursor) {
                output.append(contentsOf: match.text.utf8); cursor = match.end
            } else if byte == 0 {
                output.append(contentsOf: [0xEF, 0xBF, 0xBD]); cursor += 1
            } else { output.append(byte); cursor += 1 }
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// Labels keep their source spelling: escapes/entities are not decoded.
    /// Unicode full folding and whitespace collapse are independent of locale.
    static func label(_ text: String) -> ReferenceLabel {
        var output = ""
        var pendingSpace = false
        for scalar in text.unicodeScalars {
            if [UInt32(9), 10, 13, 32].contains(scalar.value) { pendingSpace = !output.isEmpty; continue }
            if pendingSpace { output += " "; pendingSpace = false }
            output += InlineTables.caseFold[scalar.value] ?? String(scalar)
        }
        return ReferenceLabel(output)
    }
}

/// Swift String equality canonically normalizes Unicode. CommonMark label
/// matching only folds case and ASCII label whitespace, so compare raw UTF-8.
internal struct ReferenceLabel: Hashable, Sendable {
    let bytes: [UInt8]
    init(_ value: String) { bytes = Array(value.utf8) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.bytes == rhs.bytes }
    func hash(into hasher: inout Hasher) {
        bytes.withUnsafeBufferPointer { hasher.combine(bytes: UnsafeRawBufferPointer($0)) }
    }
}
