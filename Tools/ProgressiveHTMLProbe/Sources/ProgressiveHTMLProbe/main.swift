import Foundation
import GMSetzer

func milliseconds(_ duration: Duration) -> Double {
    let parts = duration.components
    return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
}

let arguments = CommandLine.arguments
let bytes = arguments.count > 1 ? Int(arguments[1]) ?? 0 : 1_000_000
let iterations = arguments.count > 2 ? Int(arguments[2]) ?? 0 : 3
guard (1...5_000_000).contains(bytes), (1...9).contains(iterations) else {
    fatalError("Usage: ProgressiveHTMLProbe [bytes: 1...5000000] [iterations: 1...9]")
}
let unit = """
# Field Notes

A paragraph with *emphasis*, **strong**, `code`, [a link][target], äöü 😀 日本語.

- first item
- second item
  - nested item

> A quote with **markup**.

```swift
let value = 42
```

| Column | Value |
| ------ | ----: |
| a      | 1     |
| b      | 2     |

[target]: https://example.com


"""
let source = String(repeating: unit, count: max(1, (bytes + unit.utf8.count - 1) / unit.utf8.count))
let parser = MarkdownParser(profile: .gfm)
let renderer = HTMLRenderer(includeSourceRanges: true, sourceAnchorPrefix: "block-")
var samples: [[String: Any]] = []
for _ in 0..<iterations {
    let start = ContinuousClock.now
    let document = parser.parse(source)
    let parsed = ContinuousClock.now
    let htmlBytes: Int
    let rendered: ContinuousClock.Instant
    do {
        let html = renderer.render(document)
        rendered = .now
        htmlBytes = html.utf8.count
    }
    let groupStart = ContinuousClock.now
    let plan = try renderer.prepare(document)
    let prepared = ContinuousClock.now
    let first = try plan.groups.first.map { try plan.renderGroup(at: $0.ordinal) } ?? ""
    let firstReady = ContinuousClock.now
    var groupedBytes = first.utf8.count
    for group in plan.groups.dropFirst() { groupedBytes += try plan.renderGroup(at: group.ordinal).utf8.count }
    let groupsReady = ContinuousClock.now
    precondition(groupedBytes == htmlBytes)
    samples.append([
        "parse_ms": milliseconds(start.duration(to: parsed)),
        "full_html_ms": milliseconds(parsed.duration(to: rendered)),
        "html_bytes": htmlBytes,
        "nodes": document.nodes.count,
        "groups": plan.groups.count,
        "prepare_ms": milliseconds(groupStart.duration(to: prepared)),
        "first_group_ms": milliseconds(prepared.duration(to: firstReady)),
        "first_group_ready_after_parse_ms": milliseconds(groupStart.duration(to: firstReady)),
        "first_group_bytes": first.utf8.count,
        "all_groups_including_preparation_ms": milliseconds(groupStart.duration(to: groupsReady)),
    ])
}
let record: [String: Any] = ["corpus": "progressive-mixed-v1", "source_bytes": source.utf8.count,
    "iterations": iterations, "samples": samples,
    "scope": "bounded wall-clock stage probe; no allocation/peak-memory or web-view measurement"]
let json = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .prettyPrinted])
print(String(decoding: json, as: UTF8.self))
