import Foundation

func oracle(_ bytes: UnsafeBufferPointer<UInt8>, from start: Int) -> [Int] {
    var found: [Int] = []
    var offset = start
    while offset < bytes.count {
        if bytes[offset] == 10 { found.append(offset) }
        if bytes[offset] == 13 {
            found.append(offset)
            if offset + 1 < bytes.count, bytes[offset + 1] == 10 { offset += 1 }
        }
        offset += 1
    }
    return found
}

func verify() -> Int {
    var views = 0
    for length in 0...96 {
        for alignment in 0..<32 {
            for family in 0..<5 {
                let storage = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: max(1, alignment + length))
                storage.initialize(repeating: 0xa5)
                defer { _ = storage.deinitialize(); storage.deallocate() }
                var random: UInt64 = 0x7363616e
                for offset in 0..<length {
                    random = random &* 6_364_136_223_846_793_005 &+ 1
                    let byte: UInt8
                    switch family {
                    case 0: byte = 120
                    case 1: byte = 10
                    case 2: byte = offset % 2 == 0 ? 13 : 10
                    case 3: byte = offset == length - 1 ? 13 : 0xff
                    default: byte = UInt8(truncatingIfNeeded: random >> 32)
                    }
                    storage[alignment + offset] = byte
                }
                let bytes = UnsafeBufferPointer(rebasing: storage[alignment..<(alignment + length)])
                for start in Set([0, length / 2, max(0, length - 1), length]) {
                    let expected = oracle(bytes, from: start)
                    for strategy in ScanStrategy.allCases {
                        var actual: [Int] = []
                        var offset = start
                        while let found = nextTerminator(bytes, offset, strategy) {
                            precondition(found >= offset && found < bytes.count)
                            actual.append(found)
                            offset = found + 1
                            if bytes[found] == 13, offset < bytes.count, bytes[offset] == 10 { offset += 1 }
                        }
                        precondition(actual == expected,
                            "mismatch length \(length), alignment \(alignment), family \(family), start \(start), \(strategy)")
                    }
                }
                var expected = ScanFingerprint()
                for offset in oracle(bytes, from: 0) { expected.append(offset) }
                for strategy in ScanStrategy.allCases { precondition(scanTerminators(bytes, strategy) == expected) }
                views += 1
            }
        }
    }
    return views
}

struct Row: Codable {
    let corpus: String
    let bytes: Int
    let strategy: ScanStrategy
    let iterationsPerSample: Int
    let samplesNanosecondsPerScan: [Double]
    let checksums: [UInt64]

}

struct Report: Codable {
    let schema: Int
    let scope: String
    let verifiedViews: Int
    let rounds: Int
    let prefixMutation: String
    let rows: [Row]
}

func source(_ corpus: String, bytes count: Int) -> [UInt8] {
    let unit: [UInt8]
    switch corpus {
    case "lines-80-v1": unit = Array((String(repeating: "x", count: 79) + "\n").utf8)
    case "dense-crlf-v1": unit = Array("x\r\n".utf8)
    case "multibyte-v1": unit = Array("Grüße 😀 日本語 and code `x`.\r\n".utf8)
    default: unit = Array("plain text without line endings ".utf8)
    }
    var bytes = [UInt8](repeating: 32, count: count)
    for offset in 1..<count { bytes[offset] = unit[(offset - 1) % unit.count] }
    if corpus == "long-line-v1" { bytes[count - 1] = 10 }
    return bytes
}

func sample(_ bytes: UnsafeMutableBufferPointer<UInt8>, strategy: ScanStrategy,
            iterations: Int, round: Int) -> (nanoseconds: Double, checksum: UInt64) {
    var checksum: UInt64 = 0
    let clock = ContinuousClock()
    let start = clock.now
    for iteration in 0..<iterations {
        bytes[0] = UInt8(truncatingIfNeeded: iteration &+ round * 131)
        let found = scanTerminators(UnsafeBufferPointer(bytes), strategy)
        checksum &+= found.hash &+ UInt64(found.count)
    }
    let elapsed = start.duration(to: clock.now).components
    return (Double(elapsed.seconds) * 1_000_000_000 + Double(elapsed.attoseconds) / 1_000_000_000, checksum)
}

let views = verify()
var rows: [Row] = []
if !CommandLine.arguments.contains("--verify-only") {
    for corpus in ["lines-80-v1", "dense-crlf-v1", "multibyte-v1", "long-line-v1"] {
        for size in [65_536, 1_048_576, 5_242_880] {
            var bytes = source(corpus, bytes: size)
            bytes.withUnsafeMutableBufferPointer { buffer in
                // All strategies use the same iteration count and input-byte
                // sequence. Only untimed current-word8 calibration selects it.
                var iterations = 1
                while iterations < 4096 {
                    if sample(buffer, strategy: .word8, iterations: iterations, round: 0).nanoseconds >= 5_000_000 { break }
                    iterations *= 2
                }
                var timings = Dictionary(uniqueKeysWithValues: ScanStrategy.allCases.map { ($0, [Double]()) })
                var checksums = Dictionary(uniqueKeysWithValues: ScanStrategy.allCases.map { ($0, [UInt64]()) })
                for round in 0..<10 {
                    let strategies = ScanStrategy.allCases
                    let shift = round % strategies.count
                    let order = Array(strategies[shift...]) + strategies[..<shift]
                    var reference: UInt64?
                    for strategy in order {
                        let result = sample(buffer, strategy: strategy, iterations: iterations, round: round)
                        if let reference { precondition(result.checksum == reference, "timed checksum mismatch") }
                        else { reference = result.checksum }
                        timings[strategy]!.append(result.nanoseconds / Double(iterations))
                        checksums[strategy]!.append(result.checksum)
                    }
                }
                for strategy in ScanStrategy.allCases {
                    rows.append(Row(corpus: corpus, bytes: size, strategy: strategy, iterationsPerSample: iterations,
                                    samplesNanosecondsPerScan: timings[strategy]!, checksums: checksums[strategy]!))
                }
            }
        }
    }
}
let report = Report(schema: 1,
    scope: "CR/LF next-boundary traversal with CRLF combined; no line-table allocation, first counting pass, Markdown parsing or rendering.",
    verifiedViews: views, rounds: rows.isEmpty ? 0 : 10,
    prefixMutation: "Before each scan, byte zero becomes low8(iteration + round * 131); all strategies get the same sequence.",
    rows: rows)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(report), as: UTF8.self))
