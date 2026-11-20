/// Word-at-a-time search for a NUL byte.
package enum ByteSearch {
    @inline(__always)
    package static func containsZero(_ buffer: UnsafeBufferPointer<UInt8>) -> Bool {
        let low7: UInt64 = 0x7F7F_7F7F_7F7F_7F7F
        var offset = 0
        if let base = buffer.baseAddress {
            while offset + 8 <= buffer.count {
                let word = UnsafeRawPointer(base + offset).loadUnaligned(as: UInt64.self)
                if ~(((word & low7) &+ low7) | word | low7) != 0 { return true }
                offset += 8
            }
        }
        while offset < buffer.count {
            if buffer[offset] == 0 { return true }
            offset += 1
        }
        return false
    }
    /// End of an ASCII run excluding CR/LF, bounded by a checkpoint limit.
    @inline(__always)
    package static func asciiRunEnd(in buffer: UnsafeBufferPointer<UInt8>, from start: Int, to end: Int) -> Int {
        let low7: UInt64 = 0x7F7F_7F7F_7F7F_7F7F
        var offset = start
        while offset + 8 <= end {
            let word = UnsafeRawPointer(buffer.baseAddress! + offset).loadUnaligned(as: UInt64.self)
            let lf = word ^ 0x0A0A_0A0A_0A0A_0A0A, cr = word ^ 0x0D0D_0D0D_0D0D_0D0D
            if word & 0x8080_8080_8080_8080 != 0 ||
                ~(((lf & low7) &+ low7) | lf | low7) != 0 ||
                ~(((cr & low7) &+ low7) | cr | low7) != 0 { break }
            offset += 8
        }
        while offset < end, buffer[offset] < 128, buffer[offset] != 10, buffer[offset] != 13 { offset += 1 }
        return offset
    }
}

/// Word-at-a-time search for LF and CR. Each 8-byte word is tested with an
/// exact zero-byte mask, so plain text costs a few operations per 8 bytes.
package enum LineTerminators {
    private static let low7: UInt64 = 0x7F7F_7F7F_7F7F_7F7F
    private static let lf: UInt64 = 0x0A0A_0A0A_0A0A_0A0A
    private static let cr: UInt64 = 0x0D0D_0D0D_0D0D_0D0D

    /// High bit set in exactly the bytes of `value` that are zero; no carry
    /// crosses byte boundaries, so the mask has no false positives.
    @inline(__always)
    private static func zeroBytes(_ value: UInt64) -> UInt64 {
        ~(((value & low7) &+ low7) | value | low7)
    }

    @inline(__always)
    private static func mask(_ buffer: UnsafeBufferPointer<UInt8>, at offset: Int) -> UInt64 {
        let word = UInt64(littleEndian: UnsafeRawPointer(buffer.baseAddress! + offset).loadUnaligned(as: UInt64.self))
        return zeroBytes(word ^ lf) | zeroBytes(word ^ cr)
    }

    package static func count(in buffer: UnsafeBufferPointer<UInt8>) -> Int {
        var total = 0
        var offset = 0
        while offset + 8 <= buffer.count {
            total += mask(buffer, at: offset).nonzeroBitCount
            offset += 8
        }
        while offset < buffer.count {
            if buffer[offset] == 10 || buffer[offset] == 13 { total += 1 }
            offset += 1
        }
        return total
    }

    @inline(__always)
    package static func next(in buffer: UnsafeBufferPointer<UInt8>, from start: Int) -> Int? {
        var offset = start
        while offset + 8 <= buffer.count {
            let found = mask(buffer, at: offset)
            if found != 0 { return offset + found.trailingZeroBitCount >> 3 }
            offset += 8
        }
        while offset < buffer.count {
            if buffer[offset] == 10 || buffer[offset] == 13 { return offset }
            offset += 1
        }
        return nil
    }
}
