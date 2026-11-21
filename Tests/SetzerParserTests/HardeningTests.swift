import GMSetzer
import Testing

/// Bounded, deterministic mutation coverage. The seed and sample reproduce
/// each input without relying on process-randomised hashing or system entropy.
struct HardeningTests {
    private struct Generator {
        var state: UInt64
        mutating func take(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return Int((state >> 32) % UInt64(bound))
        }
    }

    private static let seeds: [UInt64] = [1, 2, 3, 4_711, 0xc0ffee, 0xdeadbeef, 65_537, UInt64.max]
    private static let implementations = [FrontMatter.implementation, Footnotes.implementation,
                                           Math.implementation, Alert.implementation, Callout.implementation]
    private static let source = """
    ---
    title: Ä😀
    ---

    # Same

    ### Skipped

    # Same

    Text [later] $x + y$[^a] ~~deleted~~.

    - [x] task
      - nested

    > [!NOTE]
    > A **bold** alert.

    > [!tip]- Title $z$[^b]
    > Callout body.

    | Left | Right |
    | :--- | ---: |
    | ä | 😀 |

    $$
    a + b
    $$

    ```math
    c + d
    ```

    ```swift
    let text = "<&>"
    ```

    [^a]: First [^b].
    [^b]: Second [^a].
    [later]: javascript:alert(1)

    <!-- comment -->
    <script>unsafe()</script>

    trailing \t
    """

    private struct Variant: Sendable {
        let name: String
        let base: Profile
        let extended: Bool
        var profile: Profile {
            Profile(name: name, extensions: base.extensions + (extended
                ? HardeningTests.implementations.map { ExtensionConfiguration($0.identifier) } : []))
        }
        func parser(collect: Bool, depth: Int) throws -> MarkdownParser {
            try MarkdownParser(profile: profile,
                extensions: extended ? HardeningTests.implementations : [],
                limits: ParserLimits(maximumContainerDepth: depth), collectSyntaxDetails: collect).validated()
        }
        var dialect: MarkdownDialect { base.name == Profile.gfm.name ? .gfm : .commonMark }
    }

    private static let variants = [
        Variant(name: "strict", base: .commonMark, extended: false),
        Variant(name: "gfm", base: .gfm, extended: false),
        Variant(name: "strict-m5", base: .commonMark, extended: true),
        Variant(name: "gfm-m5", base: .gfm, extended: true),
    ]

    private static func corpus(seed: UInt64) -> [[UInt8]] {
        let original = Array(source.utf8)
        let fragments: [[UInt8]] = [
            [], [0], [0xff, 0x80, 0xc0, 0xaf], [0xf0, 0x9f, 0x98], [0xef, 0xbb, 0xbf],
            Array("\r\n\t".utf8), Array("[^a]: [^b]\n    > [!note]- $x$\n".utf8),
            Array("[]()!*_~`$<>\\&;|#".utf8), Array("ä😀e\u{301}日本語".utf8),
        ]
        var random = Generator(state: seed)
        return (0..<32).map { sample in
            var bytes = original
            switch sample % 8 {
            case 0:
                if sample > 0 { bytes = Array(repeating: UInt8(36), count: 1 + random.take(1024)) }
            case 1:
                bytes = Array(bytes.prefix(random.take(bytes.count + 1)))
            case 2:
                bytes.insert(contentsOf: fragments[random.take(fragments.count)], at: random.take(bytes.count + 1))
            case 3:
                let lower = random.take(bytes.count + 1)
                bytes.removeSubrange(lower..<(lower + random.take(bytes.count - lower + 1)))
            case 4:
                for _ in 0..<16 { bytes[random.take(bytes.count)] = UInt8(random.take(256)) }
            case 5:
                let fragment = fragments[random.take(fragments.count)]
                bytes = Array((0..<random.take(40)).flatMap { _ in fragment })
            case 6:
                bytes = [0xef, 0xbb, 0xbf] + Array(String(repeating: "> ", count: 1 + random.take(40)).utf8)
                    + Array(bytes.suffix(random.take(bytes.count + 1)))
            default:
                bytes = Array((source + "\n\n" + source).utf8)
                bytes.insert(contentsOf: [13, 10, 0xff], at: random.take(bytes.count + 1))
            }
            return Array(bytes.prefix(1024))
        }
    }

    private static var renderer: FootnotesHTMLRenderer {
        let math: ContextualHTMLRendererHook = { context in
            Math(context.tree.document, at: context.index).map {
                .replace("<span class=\"math\">\(HTMLRenderer.escape($0.tex))</span>")
            }
        }
        return FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(HTMLRenderer(
            includeSourceRanges: true, sourceAnchorPrefix: "hardening-",
            hooks: [FrontMatter.kind: { _, _ in .replace("") }],
            contextualHooks: [Math.inlineKind: math, Math.blockKind: math], hookBehavior: .independent)))
    }

    /// Re-enter the public validator, independently of the parser's internal
    /// trusted construction path, including token owners and source segments.
    private static func validate(_ document: Document) throws {
        _ = try Document(source: document.source, nodes: document.nodes, diagnostics: document.diagnostics,
                         customLeafFallbacks: document.customLeafFallbacks, tokens: document.tokens,
                         renderingPolicy: document.renderingPolicy)
    }

    @Test(arguments: 0..<8)
    func mutatedDocumentsRetainTreePositionsFindingsAndGroupedOutput(seedIndex: Int) throws {
        let seed = Self.seeds[seedIndex]
        let corpus = Self.corpus(seed: seed)
        let renderer = Self.renderer
        for (variantIndex, variant) in Self.variants.enumerated() {
            let depth = [1, 4, 16][(seedIndex + variantIndex) % 3]
            let plain = try variant.parser(collect: false, depth: depth)
            let annotated = try variant.parser(collect: true, depth: depth)
            for (sample, bytes) in corpus.enumerated() {
                let identity = "seed=\(seed), sample=\(sample), profile=\(variant.name), depth=\(depth)"
                do {
                    let off = plain.parse(bytes: bytes), on = annotated.parse(bytes: bytes)
                    #expect(on.source == bytes && off.source == bytes, "\(identity)")
                    #expect(off.tokens == nil && on.tokens != nil, "\(identity)")
                    #expect(on.nodes == off.nodes && on.diagnostics == off.diagnostics, "\(identity)")
                    #expect(on.customLeafFallbacks == off.customLeafFallbacks && on.renderingPolicy == off.renderingPolicy, "\(identity)")
                    #expect(!on.diagnostics.contains {
                        if case .invalidExtensionResult = $0.code { return true }
                        return false
                    }, "\(identity)")
                    try Self.validate(off)
                    try Self.validate(on)

                    let positions = SourceIndex(on), tree = DocumentIndex(on)
                    #expect(positions.utf16Count == String(decoding: bytes, as: UTF8.self).utf16.count, "\(identity)")
                    #expect(positions.utf16Range(for: on.root.range) == UTF16Range(location: 0, length: positions.utf16Count), "\(identity)")
                    #expect(tree.parent(of: 0) == nil, "\(identity)")
                    for parent in on.nodes.indices {
                        for child in on.children(of: parent) {
                            #expect(tree.parent(of: child) == parent, "\(identity)")
                        }
                    }
                    for offset in 0...bytes.count {
                        if let utf16 = positions.utf16Offset(atUTF8Offset: offset) {
                            #expect(positions.utf8Offset(atUTF16Offset: utf16) == offset, "\(identity), offset=\(offset)")
                            if let position = positions.position(atUTF8Offset: offset) {
                                #expect(positions.utf8Offset(at: position) == offset, "\(identity), offset=\(offset)")
                            } else { Issue.record("Missing line/column for \(identity), offset=\(offset)") }
                            #expect(tree.node(atUTF8Offset: offset) != nil, "\(identity), offset=\(offset)")
                        }
                    }
                    for entry in tree.outline() {
                        #expect(entry.range == on.nodes[entry.node].range, "\(identity)")
                    }

                    let report = try NativeAnalyzer.analyze(on, dialect: variant.dialect,
                        configuration: NativeAnalysisConfiguration(rules: Set(NativeRule.allCases)))
                    #expect(report.source == bytes, "\(identity)")
                    for finding in report.findings { try finding.validate(in: bytes) }
                    for fix in report.findings.flatMap(\.fixes).prefix(3) {
                        let edited = try fix.applying(to: bytes)
                        let reparsed = annotated.parse(bytes: edited)
                        #expect(reparsed.source == edited, "\(identity)")
                        try Self.validate(reparsed)
                    }

                    let expected = renderer.render(on)
                    #expect(renderer.render(off) == expected, "\(identity)")
                    let plan = try renderer.prepare(on, maximumSourceBytesPerGroup: [1, 64, 32_768][sample % 3])
                    #expect(plan.mode == .structural, "\(identity)")
                    var parts = [String](repeating: "", count: plan.groups.count)
                    for group in plan.groups.reversed() { parts[group.ordinal] = try plan.renderGroup(at: group.ordinal) }
                    #expect(parts.joined() == expected, "\(identity)")
                } catch {
                    Issue.record(error, "\(identity)")
                    return
                }
            }
        }
    }

    @Test func unmutatedExtendedSeedsActuallyExerciseEverySelectedExtension() throws {
        for variant in Self.variants where variant.extended {
            let document = try variant.parser(collect: true, depth: 16).parse(Self.source)
            let kinds = Set(document.nodes.map(\.kind))
            #expect(kinds.isSuperset(of: [FrontMatter.kind, Footnotes.definitionKind, Footnotes.referenceKind,
                Math.inlineKind, Math.blockKind, Alert.kind, Callout.kind]))
            #expect(Footnotes.Index(document).notes.count == 2)
            if variant.base.name == Profile.gfm.name {
                #expect(kinds.isSuperset(of: [.table, .taskListItem, .strikethrough]))
            }
        }
    }

    @Test func deepQuotesKeepTheDeclaredFallbackWithEveryProfile() throws {
        for variant in Self.variants {
            for limit in [1, 4, 16] {
                let quote = String(repeating: "> ", count: limit + 8) + "body\n"
                var nestedAdmonitions = ""
                for level in 1...(limit + 8) {
                    nestedAdmonitions += String(repeating: "> ", count: level)
                        + (level.isMultiple(of: 2) ? "[!NOTE]\n" : "[!note]- Title\n")
                }
                for source in [quote, nestedAdmonitions] {
                    let document = try variant.parser(collect: true, depth: limit).parse(source)
                    #expect(document.diagnostics.contains { $0.code == .nestingLimitExceeded(limit) })
                    try Self.validate(document)
                    let plan = try Self.renderer.prepare(document, maximumSourceBytesPerGroup: 1)
                    var output = ""
                    try plan.forEachGroup { _, html in output += html; return true }
                    #expect(output == Self.renderer.render(document))
                }
            }
        }
    }
}
