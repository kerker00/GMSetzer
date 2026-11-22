/// UTF-8 controls keep the original hostile corpus and separately identify
/// inputs whose replacement output agrees with validation-enabled cmark.
public enum UTF8Workload: String, CaseIterable, Sendable {
    case legacyMalformed = "invalid-utf8-v1"
    case compatibleMalformed = "invalid-compatible-v1"
    case validMultibyte = "valid-multibyte-v1"

    public func source(minimumBytes: Int) -> [UInt8] {
        precondition((1...1_048_576).contains(minimumBytes))
        if self == .legacyMalformed { return HardeningWorkload.invalidUTF8.source(minimumBytes: minimumBytes) }
        let unit: [UInt8] = self == .compatibleMalformed
            ? [0xff, 0x80, 32, 0, 32, 0xf0, 0x9f, 0x98, 13, 10]
            : Array("text ä😀 日本語 with spaces\r\n".utf8)
        var bytes = Array("UTF8 ".utf8)
        bytes.reserveCapacity(minimumBytes + unit.count)
        repeat { bytes.append(contentsOf: unit) } while bytes.count < minimumBytes
        return bytes
    }
}
