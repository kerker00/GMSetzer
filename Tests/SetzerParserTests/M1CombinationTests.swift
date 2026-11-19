import GMSetzer
import Testing

struct M1CombinationTests {
    @Test(arguments: [
        "# Grüße 😀\r\n", "> quote\r\n", "- one\r\n  two\r\n", "\tcode\n",
        "```x\nz\n```\n", "<div>\nbody\n", "[a]: /u 'title'\n\nbody\n",
        "\r\n# after\rnext\n",
    ])
    func leadingBOMPreservesBytesAndShiftsOnlySourceOffsets(_ text: String) {
        let parser = MarkdownParser(collectSyntaxDetails: true)
        let plain = parser.parse(text)
        let bytes = [UInt8(0xEF), 0xBB, 0xBF] + Array(text.utf8)
        let document = parser.parse(bytes: bytes)
        #expect(document.source == bytes)
        #expect(document.root.range == SourceRange(0, bytes.count))
        #expect(HTMLRenderer().render(document) == HTMLRenderer().render(plain))
        #expect(document.nodes.count == plain.nodes.count)
        for (node, original) in zip(document.nodes.dropFirst(), plain.nodes.dropFirst()) {
            #expect(node.kind == original.kind)
            #expect(node.range == SourceRange(original.range.lowerBound + 3, original.range.upperBound + 3))
            #expect(node.sourceSegments == original.sourceSegments.map {
                SourceRange($0.lowerBound + 3, $0.upperBound + 3)
            })
            if case .referenceDefinition(let actual) = node.data,
               case .referenceDefinition(let expected) = original.data {
                for (ranges, originals) in zip(
                    [actual.syntax?.label, actual.syntax?.destination, actual.syntax?.title, actual.syntax?.markers],
                    [expected.syntax?.label, expected.syntax?.destination, expected.syntax?.title, expected.syntax?.markers]) {
                    #expect(ranges == originals?.map { SourceRange($0.lowerBound + 3, $0.upperBound + 3) })
                }
            }
        }
    }

    @Test func onlyOneBOMAtByteZeroIsIgnored() {
        let parser = MarkdownParser()
        for text in ["\u{FEFF}", "\u{FEFF}\r\n"] {
            let document = parser.parse(text)
            #expect(document.nodes.count == 1)
            #expect(document.source == Array(text.utf8))
        }
        for text in ["x\u{FEFF}y", "\n\u{FEFF}# title", "\u{FEFF}\u{FEFF}# title"] {
            let document = parser.parse(text)
            #expect(document.nodes[1].kind == .paragraph)
            #expect(HTMLRenderer().render(document).contains("\u{FEFF}"))
        }
        let partial: [UInt8] = [0xEF, 0xBB, 35, 32, 120]
        let document = parser.parse(bytes: partial)
        #expect(document.source == partial)
        #expect(document.nodes[1].kind == .paragraph)
    }

    @Test(arguments: [
        "- one\n- two\n", "- one\n\n- two\n", "- one\n  - nested\n- two\n",
        "- one\n\n  second\n", "> - one\n> - two\n", "- > quote\n- two\n",
        "- [a]: /u\n\n- two\n", "3. one\n4. two\n", "3. one\n\n4. two\n",
    ])
    func wrappingListsPreservesTightnessAndContainerBoundaries(_ text: String) {
        let document = MarkdownParser().parse(text)
        let renderer = HTMLRenderer(hooks: [.list: { node, _ in
            guard case .list(let attributes) = node.data else { return nil }
            switch attributes.style {
            case .bullet: return .wrapChildren(open: "<ul>\n", close: "</ul>\n")
            case .ordered(let start, _):
                let attribute = start == 1 ? "" : " start=\"\(start)\""
                return .wrapChildren(open: "<ol\(attribute)>\n", close: "</ol>\n")
            }
        }])
        #expect(renderer.render(document) == HTMLRenderer().render(document))
    }

    @Test func wrappersComposeAcrossBuiltInContainers() {
        let document = MarkdownParser().parse("> - one\n> - two\n")
        let renderer = HTMLRenderer(hooks: [
            .document: { _, _ in .wrapChildren(open: "<article>", close: "</article>") },
            .blockQuote: { _, _ in .wrapChildren(open: "<aside>\n", close: "</aside>\n") },
            .list: { _, _ in .wrapChildren(open: "<ul>\n", close: "</ul>\n") },
            .listItem: { _, _ in .wrapChildren(open: "<li>", close: "</li>\n") },
        ])
        #expect(renderer.render(document) == "<article><aside>\n<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n</aside>\n</article>")
        let loose = MarkdownParser().parse("- one\n\n- two\n")
        let itemRenderer = HTMLRenderer(hooks: [.listItem: { _, _ in
            .wrapChildren(open: "<li>\n", close: "</li>\n")
        }])
        #expect(itemRenderer.render(loose) == HTMLRenderer().render(loose))
        let blocks = MarkdownParser().parse("# heading\n\nparagraph\n")
        let blockRenderer = HTMLRenderer(hooks: [
            .heading: { _, _ in .wrapChildren(open: "<h2>", close: "</h2>\n") },
            .paragraph: { _, _ in .wrapChildren(open: "<section>", close: "</section>\n") },
        ])
        #expect(blockRenderer.render(blocks) == "<h2>heading</h2>\n<section>paragraph</section>\n")
    }

    static let customKind = NodeKind("example.twoLines")

    static func customParser(semanticSegments: Bool = true) -> MarkdownParser {
        let implementation = MarkdownExtension("example", blockRules: [
            BlockRule("twoLines", trigger: 58) { context in
                guard let next = context.line(at: context.lineIndex + 1) else { return nil }
                return BlockMatch(consumedLines: 2,
                    data: .custom(kind: customKind, role: .block, attributes: [:]),
                    sourceSegments: semanticSegments ? [next.contentRange] : [])
            },
        ])
        return MarkdownParser(profile: Profile(name: "example", extensions: [ExtensionConfiguration("example")]),
                              extensions: [implementation])
    }

    @Test(arguments: [
        ("::: &\r\nbody\r\n", "::: &amp;\nbody\n"),
        ("> :::\r\n> body\r\n", "<blockquote>\n:::\nbody\n</blockquote>\n"),
        ("\u{FEFF}> :::\r\n> body\r\n", "<blockquote>\n:::\nbody\n</blockquote>\n"),
        ("> :::\n> body", "<blockquote>\n:::\nbody</blockquote>\n"),
        ("- :::\n  body\n", "<ul>\n<li>\n:::\nbody\n</li>\n</ul>\n"),
        ("> - :::\r\n>   body\r\n", "<blockquote>\n<ul>\n<li>\n:::\nbody\n</li>\n</ul>\n</blockquote>\n"),
        ("- :::\n\tbody\n", "<ul>\n<li>\n:::\n  body\n</li>\n</ul>\n"),
        (">\t:::\r\n>\tbody\r\n", "<blockquote>\n  :::\n  body\n</blockquote>\n"),
    ])
    func customLeafFallbackUsesProjectedLinesNotSemanticSegments(_ fixture: (String, String)) {
        for segments in [true, false] {
            let document = Self.customParser(semanticSegments: segments).parse(fixture.0)
            #expect(document.diagnostics.isEmpty)
            #expect(document.source == Array(fixture.0.utf8))
            #expect(HTMLRenderer().render(document) == fixture.1)
        }
    }

    @Test func fallbackMetadataIsValidatedAndBuilderSnapshotsRemainIndependent() throws {
        let source = Array("raw".utf8)
        var builder = DocumentBuilder(source: source)
        let custom = try builder.append(.custom(kind: Self.customKind, role: .block, attributes: [:]),
            range: SourceRange(0, 3), sourceSegments: [SourceRange(0, 3)], fallbackLiteral: "<&>")
        let first = try builder.build()
        #expect(first.source == source)
        #expect(first.nodes[custom].sourceSegments == [SourceRange(0, 3)])
        #expect(HTMLRenderer().render(first) == "&lt;&amp;&gt;")
        try builder.finish(custom, data: first.nodes[custom].data, range: SourceRange(0, 3), fallbackLiteral: "")
        #expect(HTMLRenderer().render(try builder.build()) == "")
        #expect(HTMLRenderer().render(first) == "&lt;&amp;&gt;")
        try builder.finish(custom, data: .thematicBreak, range: SourceRange(0, 3))
        let changed = try builder.build()
        #expect(changed.customLeafFallbacks.isEmpty)
        for index in [-1, 0, 1, Int.max] {
            #expect(throws: DocumentError.invalidFallback(node: index)) {
                try Document(source: source, nodes: changed.nodes, customLeafFallbacks: [index: "invalid"])
            }
        }
        var container = DocumentBuilder(source: source)
        let parent = try container.append(.custom(kind: Self.customKind, role: .block, attributes: [:]),
            range: SourceRange(0, 3), fallbackLiteral: "invalid")
        try container.append(.text("raw"), range: SourceRange(0, 3), to: parent)
        #expect(throws: DocumentError.invalidFallback(node: parent)) { try container.build() }
    }

    @Test func handBuiltCustomLeavesCanUseRawSourceWithoutFallbackMetadata() throws {
        var builder = DocumentBuilder(source: Array("<&>".utf8))
        try builder.append(.custom(kind: Self.customKind, role: .block, attributes: [:]), range: SourceRange(0, 3))
        let document = try builder.build()
        #expect(document.customLeafFallbacks.isEmpty)
        #expect(HTMLRenderer().render(document) == "&lt;&amp;&gt;")
        #expect(MarkdownParser().parse("# Built in\n").customLeafFallbacks.isEmpty)
    }

    @Test func customFallbackEscapesInvalidSourceAndHooksCanReplaceIt() {
        let bytes = Array("> :::\n> ".utf8) + [UInt8(0xFF), 0, 38, 13, 10]
        let document = Self.customParser().parse(bytes: bytes)
        #expect(document.source == bytes)
        #expect(HTMLRenderer().render(document) == "<blockquote>\n:::\n��&amp;\n</blockquote>\n")
        let renderer = HTMLRenderer(hooks: [Self.customKind: { _, _ in .replace("<custom />\n") }])
        #expect(renderer.render(document) == "<blockquote>\n<custom />\n</blockquote>\n")
    }
}
