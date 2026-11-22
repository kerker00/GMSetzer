enum ScanStrategy: String, CaseIterable, Codable {
    case bufferScalar = "buffer-scalar"
    case spanScalar = "span-scalar"
    case word8 = "word8-current"
    case rawSpanWord8 = "raw-span-word8"
    case simd16 = "simd16"
    case simd32 = "simd32"
}

struct ScanFingerprint: Equatable {
    var count = 0
    var hash: UInt64 = 14_695_981_039_346_656_037

    mutating func append(_ offset: Int) {
        count += 1
        hash = (hash ^ UInt64(offset)) &* 1_099_511_628_211
    }
}

@inline(__always)
func scalarNext(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int) -> Int? {
    var offset = start
    while offset < bytes.count {
        if bytes[offset] == 10 || bytes[offset] == 13 { return offset }
        offset += 1
    }
    return nil
}

@inline(__always)
func spanNext(_ bytes: borrowing Span<UInt8>, _ start: Int) -> Int? {
    var offset = start
    while offset < bytes.count {
        if bytes[offset] == 10 || bytes[offset] == 13 { return offset }
        offset += 1
    }
    return nil
}

// Same 8-byte algorithm as the production baseline, with bounded RawSpan
// integer loads instead of UnsafeRawPointer arithmetic. This isolates the
// view/access change from the scalar-versus-word algorithm difference.
@inline(__always)
func rawSpanNext(_ bytes: borrowing RawSpan, _ start: Int) -> Int? {
    let low7: UInt64 = 0x7F7F_7F7F_7F7F_7F7F
    var offset = start
    while offset + 8 <= bytes.byteCount {
        let word = UInt64(littleEndian: bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: UInt64.self))
        let lf = word ^ 0x0A0A_0A0A_0A0A_0A0A, cr = word ^ 0x0D0D_0D0D_0D0D_0D0D
        let found = ~(((lf & low7) &+ low7) | lf | low7) | ~(((cr & low7) &+ low7) | cr | low7)
        if found != 0 { return offset + (found.trailingZeroBitCount >> 3) }
        offset += 8
    }
    while offset < bytes.byteCount {
        let byte = bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: UInt8.self)
        if byte == 10 || byte == 13 { return offset }
        offset += 1
    }
    return nil
}

@inline(__always)
func simd16Next(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int) -> Int? {
    var offset = start
    while offset + 16 <= bytes.count {
        let word = UnsafeRawPointer(bytes.baseAddress! + offset).loadUnaligned(as: SIMD16<UInt8>.self)
        let hits = (word .== SIMD16(repeating: 10)) .| (word .== SIMD16(repeating: 13))
        if hits != SIMDMask(repeating: false) {
            for lane in 0..<16 where hits[lane] { return offset + lane }
        }
        offset += 16
    }
    return scalarNext(bytes, offset)
}

@inline(__always)
func simd32Next(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int) -> Int? {
    var offset = start
    while offset + 32 <= bytes.count {
        let word = UnsafeRawPointer(bytes.baseAddress! + offset).loadUnaligned(as: SIMD32<UInt8>.self)
        let hits = (word .== SIMD32(repeating: 10)) .| (word .== SIMD32(repeating: 13))
        if hits != SIMDMask(repeating: false) {
            for lane in 0..<32 where hits[lane] { return offset + lane }
        }
        offset += 32
    }
    return scalarNext(bytes, offset)
}

@inline(__always)
func nextTerminator(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ strategy: ScanStrategy) -> Int? {
    switch strategy {
    case .bufferScalar: scalarNext(bytes, start)
    case .spanScalar: spanNext(bytes.span, start)
    case .word8: LineTerminators.next(in: bytes, from: start)
    case .rawSpanWord8: rawSpanNext(UnsafeRawBufferPointer(bytes).bytes, start)
    case .simd16: simd16Next(bytes, start)
    case .simd32: simd32Next(bytes, start)
    }
}

@inline(__always)
private func collect(_ bytes: UnsafeBufferPointer<UInt8>, next: (Int) -> Int?) -> ScanFingerprint {
    var result = ScanFingerprint()
    var offset = 0
    while let found = next(offset) {
        result.append(found)
        offset = found + 1
        if bytes[found] == 13, offset < bytes.count, bytes[offset] == 10 { offset += 1 }
    }
    return result
}

// Keep the scan behind a call boundary. The benchmark mutates one input byte
// before every call, so repeated scans cannot be hoisted out of the timing loop.
@inline(never)
func scanTerminators(_ bytes: UnsafeBufferPointer<UInt8>, _ strategy: ScanStrategy) -> ScanFingerprint {
    switch strategy {
    case .bufferScalar: return collect(bytes) { scalarNext(bytes, $0) }
    case .word8: return collect(bytes) { LineTerminators.next(in: bytes, from: $0) }
    case .simd16: return collect(bytes) { simd16Next(bytes, $0) }
    case .simd32: return collect(bytes) { simd32Next(bytes, $0) }
    case .rawSpanWord8:
        let span = UnsafeRawBufferPointer(bytes).bytes
        var result = ScanFingerprint()
        var offset = 0
        while let found = rawSpanNext(span, offset) {
            result.append(found)
            offset = found + 1
            if span.unsafeLoadUnaligned(fromByteOffset: found, as: UInt8.self) == 13,
               offset < span.byteCount,
               span.unsafeLoadUnaligned(fromByteOffset: offset, as: UInt8.self) == 10 { offset += 1 }
        }
        return result
    case .spanScalar:
        // A span cannot escape into a closure. Keep this borrowed view local
        // for the entire scan rather than reconstructing it for each line.
        let span = bytes.span
        var result = ScanFingerprint()
        var offset = 0
        while let found = spanNext(span, offset) {
            result.append(found)
            offset = found + 1
            if span[found] == 13, offset < span.count, span[offset] == 10 { offset += 1 }
        }
        return result
    }
}
