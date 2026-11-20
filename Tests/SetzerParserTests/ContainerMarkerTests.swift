import GMSetzer
import Testing

struct ContainerMarkerTests {
    static func tokens(_ document: Document, _ role: String) -> [SyntaxToken] {
        (document.tokens ?? []).filter { $0.role == role }
    }

    static func spelling(_ token: SyntaxToken, in document: Document) -> String {
        String(decoding: document.source[token.range.lowerBound..<token.range.upperBound], as: UTF8.self)
    }

    @Test func quotesOwnOnlyTheirExplicitPrefixesIncludingBlankLines() throws {
        let document = MarkdownParser(collectSyntaxDetails: true)
            .parse("> outer\n> > inner\nlazy\n> >\n> tail\n")
        let quotes = document.nodes.indices.filter { document.nodes[$0].kind == .blockQuote }
        #expect(quotes.count == 2)
        let outer = try #require(quotes.first)
        let inner = try #require(quotes.last)
        let tokens = Self.tokens(document, "core.blockQuote.marker")
        #expect(tokens.map(\.range) == [0, 8, 10, 23, 25, 27].map { SourceRange($0, $0 + 1) })
        #expect(tokens.map(\.owner) == [outer, outer, inner, outer, inner, outer])
        #expect(tokens.allSatisfy { Self.spelling($0, in: document) == ">" })
    }

    @Test func listItemsOwnOriginalBulletOrOrderedSpellingWithoutPadding() {
        let document = MarkdownParser(collectSyntaxDetails: true)
            .parse("- a\n+ b\n* c\n\n003) d\n004) e\n\n9. f\n")
        let tokens = Self.tokens(document, "core.list.marker")
        #expect(tokens.map(\.range) == [SourceRange(0, 1), SourceRange(4, 5), SourceRange(8, 9),
            SourceRange(13, 17), SourceRange(20, 24), SourceRange(28, 30)])
        #expect(tokens.map { Self.spelling($0, in: document) } == ["-", "+", "*", "003)", "004)", "9."])
        #expect(tokens.map(\.owner) == document.nodes.indices.filter { document.nodes[$0].kind == .listItem })
    }

    @Test func nestedMarkersKeepBOMUnicodeCRLFAndUTF16Offsets() {
        let source = "\u{FEFF}> - Ä😀\r\n>   1) β\r\n>      > z\r\n"
        let document = MarkdownParser(collectSyntaxDetails: true).parse(source)
        #expect(document.source == Array(source.utf8))
        #expect(Self.tokens(document, "core.blockQuote.marker").map(\.range)
            == [3, 15, 26, 33].map { SourceRange($0, $0 + 1) })
        #expect(Self.tokens(document, "core.list.marker").map(\.range) == [SourceRange(5, 6), SourceRange(19, 21)])
        let markers = (Self.tokens(document, "core.blockQuote.marker") + Self.tokens(document, "core.list.marker"))
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
        let positions = SourceIndex(document)
        #expect(markers.map { positions.utf16Offset(atUTF8Offset: $0.range.lowerBound) } == [1, 3, 10, 14, 20, 27])
    }

    @Test func partialTabsNeverBecomePartOfAMarker() {
        let document = MarkdownParser(collectSyntaxDetails: true).parse(">\t> -\tx\r\n")
        #expect(Self.tokens(document, "core.blockQuote.marker").map(\.range) == [SourceRange(0, 1), SourceRange(2, 3)])
        #expect(Self.tokens(document, "core.list.marker").map(\.range) == [SourceRange(4, 5)])
        let continued = MarkdownParser(collectSyntaxDetails: true).parse("-\t> a\n\t> b\n")
        #expect(Self.tokens(continued, "core.list.marker").map(\.range) == [SourceRange(0, 1)])
        #expect(Self.tokens(continued, "core.blockQuote.marker").map(\.range) == [SourceRange(2, 3), SourceRange(7, 8)])
    }

    @Test func taskCheckboxesAndListMarkersAreSeparateTokensOfTheSameItem() {
        let source = "- [ ] a\n- [X] b\n"
        let document = MarkdownParser(profile: .gfm, collectSyntaxDetails: true).parse(source)
        let markers = Self.tokens(document, "core.list.marker")
        let boxes = Self.tokens(document, "gfm.tasklist.marker")
        #expect(markers.map(\.range) == [SourceRange(0, 1), SourceRange(8, 9)])
        #expect(boxes.map(\.range) == [SourceRange(2, 5), SourceRange(10, 13)])
        #expect(markers.map(\.owner) == boxes.map(\.owner))
        #expect(markers.map { document.nodes[$0.owner].kind } == [.taskListItem, .taskListItem])
        let common = MarkdownParser(collectSyntaxDetails: true).parse(source)
        #expect(Self.tokens(common, "core.list.marker").map(\.range) == markers.map(\.range))
        #expect(Self.tokens(common, "gfm.tasklist.marker").isEmpty)
    }

    @Test func literalCodeEscapesThematicBreaksAndSetextLinesDoNotProduceMarkers() {
        for source in ["```\n> - literal\n```\n", "    > quote\n    - item\n", "\\> quote\n\\- item\n",
                       "paragraph\n2. literal\n", "heading\n-\n", "* * *\n"] {
            let document = MarkdownParser(collectSyntaxDetails: true).parse(source)
            #expect(Self.tokens(document, "core.blockQuote.marker").isEmpty, "\(source)")
            #expect(Self.tokens(document, "core.list.marker").isEmpty, "\(source)")
        }
        let fenced = MarkdownParser(collectSyntaxDetails: true).parse("> ```\n> > - code\n> ```\n")
        #expect(Self.tokens(fenced, "core.blockQuote.marker").map(\.range)
            == [SourceRange(0, 1), SourceRange(6, 7), SourceRange(17, 18)])
        #expect(Self.tokens(fenced, "core.list.marker").isEmpty)
        #expect(Self.tokens(fenced, "core.fence.open").count == 1)
        #expect(Self.tokens(fenced, "core.fence.close").count == 1)
    }

    @Test func disabledRulesAndDepthFallbackDoNotInventMarkers() {
        let profile = Profile(name: "literal", disabledRules: ["core.blockQuote", "core.list"])
        let disabled = MarkdownParser(profile: profile, collectSyntaxDetails: true).parse("> a\n- b\n")
        #expect(Self.tokens(disabled, "core.blockQuote.marker").isEmpty)
        #expect(Self.tokens(disabled, "core.list.marker").isEmpty)
        let limited = MarkdownParser(limits: ParserLimits(maximumContainerDepth: 2), collectSyntaxDetails: true)
            .parse("> > > x\n")
        #expect(Self.tokens(limited, "core.blockQuote.marker").map(\.range) == [SourceRange(0, 1), SourceRange(2, 3)])
        #expect(limited.diagnostics.map(\.code) == [.nestingLimitExceeded(2)])
        let list = MarkdownParser(limits: ParserLimits(maximumContainerDepth: 1), collectSyntaxDetails: true).parse("- x\n")
        #expect(Self.tokens(list, "core.list.marker").isEmpty)
    }

    @Test func projectedExtensionChildrenRetainOriginalRangesAndRemappedOwners() throws {
        let parser = try MarkdownParser(profile: Profile(name: "probe", extensions: [ExtensionConfiguration("footnote")]),
            extensions: [ContainerExtensionTests.implementation], collectSyntaxDetails: true).validated()
        let document = parser.parse("[^x]: > *a*\n    > - b\n")
        let custom = try #require(document.nodes.firstIndex { $0.kind == ContainerExtensionTests.footnote })
        let quotes = Self.tokens(document, "core.blockQuote.marker")
        #expect(quotes.map(\.range) == [SourceRange(6, 7), SourceRange(16, 17)])
        #expect(quotes.allSatisfy { document.children(of: custom).contains($0.owner) })
        let list = try #require(Self.tokens(document, "core.list.marker").first)
        #expect(list.range == SourceRange(18, 19))
        #expect(document.nodes[list.owner].kind == .listItem)
        #expect(document.nodes.contains { $0.kind == .emphasis })
        #expect(document.diagnostics.allSatisfy { if case .extensionFinding = $0.code { true } else { false } })
    }

    @Test func quoteProvenanceSurvivesATransformIntoACustomContainer() {
        let parser = MarkdownParser(profile: Profile(name: "probe", extensions: [ExtensionConfiguration("alert")]),
            extensions: [TransformTests.alerts], collectSyntaxDetails: true)
        let document = parser.parse("> [!NOTE] *body*\n> - item\n")
        let quotes = Self.tokens(document, "core.blockQuote.marker")
        #expect(quotes.count == 2)
        #expect(quotes.allSatisfy { document.nodes[$0.owner].kind == TransformTests.kind })
        #expect(Self.tokens(document, "core.list.marker").count == 1)
        #expect(document.diagnostics.isEmpty)
    }

    @Test func multilineExtensionsCaptureOnlyConsumedParentPrefixes() {
        let kind = NodeKind("opaque.block")
        let opaque = MarkdownExtension("opaque", nodeKinds: [kind], blockRules: [
            BlockRule("block", trigger: 64) { context in
                guard context.line(at: context.lineIndex + 1) != nil else { return nil }
                // Look ahead without consuming this third line. Its parent
                // prefix must only be recorded later by the normal parser.
                _ = context.line(at: context.lineIndex + 2)
                return BlockMatch(consumedLines: 2,
                    data: .custom(kind: kind, role: .block, attributes: [:]))
            },
        ])
        for (implementation, source, offsets) in [
            (ContainerExtensionTests.implementation, "> [^x]: body\n>     second\n> outside\n", [0, 13, 26]),
            (opaque, "> @block\n> body\n> tail\n", [0, 9, 16]),
        ] {
            let profile = Profile(name: "probe", extensions: [ExtensionConfiguration(implementation.identifier)])
            let document = MarkdownParser(profile: profile, extensions: [implementation], collectSyntaxDetails: true).parse(source)
            let tokens = Self.tokens(document, "core.blockQuote.marker")
            #expect(tokens.map(\.range) == offsets.map { SourceRange($0, $0 + 1) })
            #expect(Set(tokens).count == tokens.count)
            #expect(tokens.allSatisfy { document.nodes[$0.owner].kind == .blockQuote })
            #expect(document.nodes == MarkdownParser(profile: profile, extensions: [implementation]).parse(source).nodes)
        }
    }

    @Test func annotationModePreservesArbitraryByteTreesAndDiagnostics() {
        var state: UInt64 = 4711
        let alphabet = Array(">-+*012.) #=~`\t\r\naÄ😀".utf8) + [0, 255]
        for profile in [Profile.commonMark, .gfm] {
            let plain = MarkdownParser(profile: profile, limits: ParserLimits(maximumContainerDepth: 12))
            let annotated = MarkdownParser(profile: profile, limits: ParserLimits(maximumContainerDepth: 12), collectSyntaxDetails: true)
            for _ in 0..<256 {
                var bytes: [UInt8] = []
                for _ in 0..<256 {
                    state = state &* 6_364_136_223_846_793_005 &+ 1
                    bytes.append(alphabet[Int((state >> 32) % UInt64(alphabet.count))])
                }
                let off = plain.parse(bytes: bytes)
                let on = annotated.parse(bytes: bytes)
                #expect(off.tokens == nil)
                #expect(on.tokens != nil)
                #expect(on.source == off.source)
                #expect(on.nodes == off.nodes)
                #expect(on.diagnostics == off.diagnostics)
                let markers = Self.tokens(on, "core.blockQuote.marker") + Self.tokens(on, "core.list.marker")
                #expect(Set(markers).count == markers.count)
            }
        }
    }
}
