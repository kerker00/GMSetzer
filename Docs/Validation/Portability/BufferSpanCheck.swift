func bufferSpanCount(_ bytes: [UInt8]) -> Int { bytes.withUnsafeBufferPointer { $0.span.count } }
