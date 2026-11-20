import GMSetzer
let clock = ContinuousClock()
var total = 0
for size in [100_000, 1_000_000, 5_000_000] {
    let text = Corpus.document(bytes: size)
    let parser = MarkdownParser()
    total += parser.parse(text).nodes.count
    var times: [Double] = []
    for _ in 0..<3 {
        let start = clock.now
        let document = parser.parse(text)
        let duration = start.duration(to: clock.now)
        total += document.nodes.count
        times.append(Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15)
    }
    print("mixed-v1 bytes=\(text.utf8.count) median_ms=\(times.sorted()[1])")
}
print("consumed_nodes=\(total)")
