import GMSetzer

struct Generator {
    var state: UInt64 = 0x6d375f7374726573
    mutating func next(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return Int((state >> 32) % UInt64(bound))
    }
}

let extensions = [FrontMatter.implementation, Footnotes.implementation, Math.implementation,
                  Alert.implementation, Callout.implementation]
let profiles = [Profile.commonMark, .gfm,
    Profile(name: "commonmark-m5", extensions: extensions.map { ExtensionConfiguration($0.identifier) }),
    Profile(name: "gfm-m5", extensions: Profile.gfm.extensions + extensions.map { ExtensionConfiguration($0.identifier) })]
let seed = Array("""
---
title: ä😀
---

# Title

Text **strong** $x$ [link](https://example.com) and [^a].

> [!tip]- Title $z$
> body

[^a]: note [^a]

| a | b |
| - | - |
| x | y |

```math
x + y
```
""".utf8)
let fragments: [[UInt8]] = [seed, Array("😀 ä 日本語\r\n".utf8),
    [0xff, 0x80, 0xc0, 0xaf, 0, 0xf0, 0x9f, 0x98, 13, 10],
    Array(("x " + String(repeating: "[", count: 4_000)).utf8),
    Array((String(repeating: "> ", count: 256) + "body\n").utf8),
    Array(("x " + String(repeating: "*", count: 1_023) + "a" + String(repeating: "*", count: 1_022)).utf8)]
let count = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 1_024
precondition((1...16_384).contains(count))
var generator = Generator()
let renderer = FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(HTMLRenderer()))
for sample in 0..<count {
    var bytes = fragments[sample % fragments.count]
    for _ in 0..<(1 + generator.next(12)) {
        switch generator.next(4) {
        case 0 where !bytes.isEmpty: bytes.removeSubrange(generator.next(bytes.count)..<bytes.count)
        case 1 where !bytes.isEmpty: bytes[generator.next(bytes.count)] = UInt8(generator.next(256))
        case 2: bytes.insert(UInt8(generator.next(256)), at: generator.next(bytes.count + 1))
        default: bytes.append(contentsOf: fragments[generator.next(fragments.count)].prefix(256))
        }
        if bytes.count > 4_096 { bytes.removeSubrange(4_096..<bytes.count) }
    }
    for (profileIndex, profile) in profiles.enumerated() {
        let implementations: [MarkdownExtension] = profileIndex < 2 ? [] : extensions
        let plain = try MarkdownParser(profile: profile, extensions: implementations).validated().parse(bytes: bytes)
        let annotated = try MarkdownParser(profile: profile, extensions: implementations,
            collectSyntaxDetails: true).validated().parse(bytes: bytes)
        precondition(plain.source == bytes && annotated.source == bytes, "source sample \(sample) profile \(profileIndex)")
        precondition(plain.nodes == annotated.nodes && plain.diagnostics == annotated.diagnostics,
            "annotation sample \(sample) profile \(profileIndex)")
        precondition(plain.customLeafFallbacks == annotated.customLeafFallbacks
            && plain.renderingPolicy == annotated.renderingPolicy)
        precondition(!annotated.diagnostics.contains {
            if case .invalidExtensionResult = $0.code { return true }
            return false
        }, "extension result sample \(sample) profile \(profileIndex)")
        _ = try Document(source: annotated.source, nodes: annotated.nodes, diagnostics: annotated.diagnostics,
            customLeafFallbacks: annotated.customLeafFallbacks, tokens: annotated.tokens,
            renderingPolicy: annotated.renderingPolicy)
        precondition(SourceIndex(annotated).utf16Count == String(decoding: bytes, as: UTF8.self).utf16.count)
        let expected = renderer.render(plain)
        precondition(renderer.render(annotated) == expected)
        let plan = try renderer.prepare(annotated, maximumSourceBytesPerGroup: 64)
        let groups = try plan.groups.reversed().map { ($0.ordinal, try plan.renderGroup(at: $0.ordinal)) }
        precondition(groups.sorted { $0.0 < $1.0 }.map(\.1).joined() == expected,
            "groups sample \(sample) profile \(profileIndex)")
    }
}
print("{\"inputs\":\(count),\"profile_pairs\":\(count * 4),\"parses\":\(count * 8),\"max_bytes\":4096,\"status\":\"passed\"}")
