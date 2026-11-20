import GMSetzer
import Testing

struct FootnoteTests {
    static func parser(base: Profile = .commonMark, disabled: Set<String> = [], collect: Bool = true) -> MarkdownParser {
        MarkdownParser(profile: Profile(name: "footnotes-test",
            extensions: base.extensions + [ExtensionConfiguration(Footnotes.identifier)],
            disabledRules: base.disabledRules.union(disabled), ruleOrder: base.ruleOrder),
            extensions: [Footnotes.implementation], collectSyntaxDetails: collect)
    }
    static let renderer = FootnotesHTMLRenderer()

    @Test func forwardAndBackwardReferencesRenderAtTheEndWithoutMovingSourceNodes() throws {
        for source in ["Text[^a].\n\n[^a]: A *note*.\n", "[^a]: A *note*.\n\nText[^a].\n"] {
            let document = try Self.parser().validated().parse(source)
            let notes = Footnotes.Index(document).notes
            #expect(notes.count == 1)
            let note = try #require(notes.first)
            #expect(note.number == 1 && note.references.count == 1)
            #expect(Footnotes.label(document.nodes[note.definition]) == "a")
            #expect(document.nodes.contains { $0.kind == .emphasis })
            #expect(document.source == Array(source.utf8))
            #expect(document.diagnostics.isEmpty)
            #expect(Self.renderer.render(document) == "<p>Text<sup><a href=\"#fn-note-1\" id=\"fn-ref-1-1\" data-footnote-ref=\"\">1</a></sup>.</p>\n<section class=\"footnotes\" data-footnotes=\"\">\n<ol>\n<li id=\"fn-note-1\">\n<p>A <em>note</em>.</p>\n<p><a href=\"#fn-ref-1-1\" data-footnote-backref=\"\" aria-label=\"Back to reference 1.1\">↩</a></p>\n</li>\n</ol>\n</section>\n")
        }
    }

    @Test func firstCallOrderRepeatedCallsAndFirstDefinitionWins() throws {
        let document = Self.parser().parse("[^a]: Alpha\n[^b]: Beta\n[^a]: Duplicate\n\nB[^b] A[^a] B[^b].\n")
        let notes = Footnotes.Index(document).notes
        #expect(notes.map { Footnotes.label(document.nodes[$0.definition]) } == ["b", "a"])
        #expect(notes.map(\.number) == [1, 2])
        #expect(notes.map { $0.references.count } == [2, 1])
        let html = Self.renderer.render(document)
        #expect(html.contains("id=\"fn-ref-1-2\""))
        #expect(html.contains("href=\"#fn-ref-1-2\""))
        #expect(!html.contains("Duplicate"))
        #expect(html.contains("<p>Beta</p>") && html.contains("<p>Alpha</p>"))
        for note in notes {
            guard case .custom(_, _, let attributes) = document.nodes[note.definition].data else { Issue.record(); continue }
            #expect(attributes["number"] == .integer(note.number))
        }
    }

    @Test func multilineDefinitionsParseParagraphsListsQuotesAndCode() {
        let source = "Text[^a]\n\n[^a]: First **paragraph**.\n    continued\n\n    Second paragraph.\n\n    - item\n\n    > quote\n\n        code\n\nOutside\n"
        let document = Self.parser().parse(source)
        let html = Self.renderer.render(document)
        #expect(document.diagnostics.isEmpty)
        #expect(html.contains("<p>First <strong>paragraph</strong>.\ncontinued</p>"))
        #expect(html.contains("<p>Second paragraph.</p>"))
        #expect(html.contains("<ul>\n<li>item</li>\n</ul>"))
        #expect(html.contains("<blockquote>\n<p>quote</p>\n</blockquote>"))
        #expect(html.contains("<pre><code>code\n</code></pre>"))
        #expect(html.hasPrefix("<p>Text"))
        #expect(html.contains("<p>Outside</p>\n<section"))
    }

    @Test func emptyBodiesAndTabsAndIndentationUseCoreProjection() throws {
        for prefix in ["", " ", "  ", "   "] {
            let document = Self.parser().parse("use[^a]\n\n" + prefix + "[^a]:\n\tcontinued\n")
            #expect(Footnotes.Index(document).notes.count == 1)
            #expect(Self.renderer.render(document).contains("<p>continued</p>"))
            #expect(document.diagnostics.isEmpty)
        }
        let empty = Self.parser().parse("use[^a]\n\n[^a]:")
        #expect(Footnotes.Index(empty).notes.count == 1)
        #expect(Self.renderer.render(empty).contains("<li id=\"fn-note-1\">\n<p><a"))
        #expect(empty.diagnostics.isEmpty)
        let code = Self.parser().parse("use[^a]\n\n    [^a]: code\n")
        #expect(Footnotes.Index(code).notes.isEmpty)
        #expect(!code.nodes.contains { $0.kind == Footnotes.definitionKind })
    }

    @Test func explicitContinuationStopsBeforeAnUnindentedBodyLine() {
        let document = Self.parser().parse("use[^a]\n[^a]: note\nbody\n")
        #expect(Self.renderer.render(document).contains("<p>body</p>\n<section"))
        #expect(Self.renderer.render(document).contains("<p>note</p>"))
    }

    @Test func missingAndMalformedLabelsRetainOrdinaryMarkdown() {
        for label in ["", "a b", "a\tb", "a[b", String(repeating: "a", count: 1_000)] {
            let source = "Text[^\(label)]\n\n[^\(label)]: note\n"
            let original = MarkdownParser(collectSyntaxDetails: true).parse(source)
            let extended = Self.parser().parse(source)
            #expect(extended.nodes == original.nodes)
            #expect(extended.tokens == original.tokens)
            #expect(Footnotes.Index(extended).notes.isEmpty)
        }
        let missing = Self.parser().parse("Undefined[^missing] [^link](https://example.com).\n")
        #expect(Footnotes.Index(missing).notes.isEmpty)
        #expect(Self.renderer.render(missing) == "<p>Undefined[^missing] <a href=\"https://example.com\">^link</a>.</p>\n")
    }

    @Test func unicodeFullCaseFoldingDoesNotCanonicallyNormalizeOrDecodeLabels() {
        let document = Self.parser().parse("[^STRASSE] [^ä] [^é] [^e\u{301}] [^a&b]\n\n[^straße]: one\n[^Ä]: two\n[^é]: three\n[^a&amp;b]: four\n")
        let notes = Footnotes.Index(document).notes
        #expect(notes.map { Footnotes.label(document.nodes[$0.definition]) } == ["straße", "Ä", "é"])
        #expect(Self.renderer.render(document).contains("[^e\u{301}] [^a&amp;b]"))
    }

    @Test func escapedBracketsCanBePartOfAnOpaqueLabel() throws {
        let document = Self.parser().parse("Use[^a\\]b] and[^a\\[b].\n\n[^a\\]b]: one\n[^a\\[b]: two\n")
        #expect(Footnotes.Index(document).notes.count == 2)
        #expect(document.diagnostics.isEmpty)
    }

    @Test func protectedCodeEscapesHTMLLinksAndImagesDoNotBecomeCalls() {
        let source = "`[^a]` \\[^a] [link[^a]](/url) ![alt[^a]](/image) <i title=\"[^a]\">\n\n```\n[^a]\n```\n\n[^a]: note\n"
        let document = Self.parser().parse(source)
        #expect(!document.nodes.contains { $0.kind == Footnotes.referenceKind })
        #expect(Footnotes.Index(document).notes.isEmpty)
        #expect(!Self.renderer.render(document).contains("data-footnotes"))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func quotedAndListDefinitionsKeepExactCRLFMarkerRangesAndOwners() throws {
        let source = "> [^Ä]: body\r\n>     continued\r\n\r\n- use[^Ä]\r\n"
        let document = Self.parser().parse(source)
        let note = try #require(Footnotes.Index(document).notes.first)
        let owner = note.definition
        let tokens = (document.tokens ?? []).filter { $0.role.hasPrefix("footnotes.definition.") }
        #expect(tokens.map(\.owner) == [owner, owner, owner])
        #expect(tokens.map { String(decoding: document.source[$0.range.lowerBound..<$0.range.upperBound], as: UTF8.self) } == ["[^", "Ä", "]:"])
        #expect(tokens.map(\.range) == [SourceRange(2, 4), SourceRange(4, 6), SourceRange(6, 8)])
        #expect(document.nodes[owner].range.lowerBound == 2)
        #expect(document.nodes[note.references[0]].range.count == 5)
        #expect(document.diagnostics.isEmpty)
        #expect(Self.renderer.render(document).contains("<p>body\ncontinued</p>"))
    }

    @Test func BOMLineEndingsInvalidUTF8AndNULKeepTheOriginalSnapshot() {
        for ending in ["\n", "\r\n", "\r"] {
            let bytes = [UInt8(0xEF), 0xBB, 0xBF] + Array(("Use[^a]" + ending + "[^a]: ").utf8) + [255, 0] + Array(ending.utf8)
            let document = Self.parser().parse(bytes: bytes)
            #expect(document.source == bytes)
            #expect(Footnotes.Index(document).notes.count == 1)
            #expect(Self.renderer.render(document).contains("�"))
            #expect(!Self.renderer.render(document).utf8.contains(0))
            #expect(document.diagnostics.isEmpty)
        }
    }

    @Test func annotationsOffPreserveSemanticsAndNumbering() {
        let source = "Use[^a] again[^a].\n\n[^a]: **Body**\n"
        let on = Self.parser().parse(source), off = Self.parser(collect: false).parse(source)
        #expect(on.nodes == off.nodes)
        #expect(on.diagnostics == off.diagnostics)
        #expect(on.customLeafFallbacks == off.customLeafFallbacks)
        #expect(Footnotes.Index(on) == Footnotes.Index(off))
        #expect(Self.renderer.render(on) == Self.renderer.render(off))
        #expect(off.tokens == nil)
        #expect(on.tokens?.filter { $0.role.hasPrefix("footnotes.reference.") }.count == 6)
    }

    @Test func optInAndRuleDisablingAreIndependent() throws {
        let source = "Use[^a]\n\n[^a]: body\n"
        for base in [Profile.commonMark, .gfm] {
            let plain = MarkdownParser(profile: base, collectSyntaxDetails: true).parse(source)
            let supplied = MarkdownParser(profile: base, extensions: [Footnotes.implementation], collectSyntaxDetails: true).parse(source)
            #expect(plain.nodes == supplied.nodes && plain.tokens == supplied.tokens)
        }
        for disabled: Set<String> in [["footnotes.definition"], ["footnotes.reference"], ["footnotes.number"]] {
            let parser = try Self.parser(disabled: disabled).validated()
            let document = parser.parse(source)
            #expect(document.diagnostics.isEmpty)
            if disabled.contains("footnotes.definition") { #expect(Footnotes.Index(document).notes.isEmpty) }
            if disabled.contains("footnotes.reference") { #expect(!document.nodes.contains { $0.kind == Footnotes.referenceKind }) }
            if disabled.contains("footnotes.number") {
                let call = try #require(document.nodes.first { $0.kind == Footnotes.referenceKind })
                if case .custom(_, _, let attributes) = call.data { #expect(attributes["number"] == nil) }
                #expect(Footnotes.Index(document).notes.count == 1)
            }
        }
    }

    @Test func bodyAndCitedNoteGraphOrderIsFiniteEvenWithCycles() {
        let document = Self.parser().parse("Call[^b] then[^a].\n\n[^a]: A[^b]\n[^b]: B[^c] self[^b]\n[^c]: C[^a]\n[^unused]: Unused[^d]\n[^d]: hidden\n")
        let notes = Footnotes.Index(document).notes
        #expect(notes.map { Footnotes.label(document.nodes[$0.definition]) } == ["b", "a", "c"])
        #expect(notes.map { $0.references.count } == [3, 2, 1])
        let html = Self.renderer.render(document)
        #expect(!html.contains("Unused") && !html.contains("hidden"))
        #expect(html.contains("#fn-ref-1-3"))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func gfmTablesTasksAndAutolinksWorkInsideAndOutsideNotes() throws {
        let document = try Self.parser(base: .gfm).validated().parse("| a |\n| - |\n| use[^a] |\n\n- [x] task[^a]\n\n[^a]: ~~done~~ www.example.org\n")
        #expect(Footnotes.Index(document).notes.first?.references.count == 2)
        let html = Self.renderer.render(document)
        #expect(html.contains("<table>") && html.contains("<input checked"))
        #expect(html.contains("<del>done</del>") && html.contains("href=\"http://www.example.org\""))
        #expect(document.renderingPolicy.contains(.filtersDisallowedRawHTML))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func renderingPreservesURLSafetyHooksAnchorsAndEscapesGeneratedAttributes() {
        let document = Self.parser().parse("Call[^a]\n\n[^a]: [bad](javascript:alert(1)) <script>bad</script>\n")
        let base = HTMLRenderer(includeSourceRanges: true, sourceAnchorPrefix: "source-",
            hooks: [.paragraph: { _, _ in .wrapChildren(open: "<p class=\"custom\">", close: "</p>\n") }])
        let html = FootnotesHTMLRenderer(renderer: base, idPrefix: "\"<&_", backlinkLabel: "Back \"<&").render(document)
        #expect(html.contains("<p class=\"custom\">Call"))
        #expect(html.contains("href=\"\""))
        #expect(!html.contains("<script>"))
        #expect(html.contains("aria-label=\"Back &quot;&lt;&amp; 1.1\""))
        #expect(html.contains("id=\"_22_3c_26_5fnote-1\""))
        let plain = HTMLRenderer().render(document)
        #expect(plain.contains("[^a]") && plain.contains("bad"))
    }

    @Test func unusedDefinitionsAreHiddenAndDefaultRenderingRemainsCallerPolicy() {
        let document = Self.parser().parse("Body\n\n[^unused]: hidden\n")
        #expect(Self.renderer.render(document) == "<p>Body</p>\n")
        #expect(HTMLRenderer().render(document).contains("hidden"))
    }

    @Test func frontMatterAndFootnotesComposeWithoutInterpretingMetadata() throws {
        let profile = Profile(name: "combined", extensions: Profile.gfm.extensions +
            [ExtensionConfiguration(FrontMatter.identifier), ExtensionConfiguration(Footnotes.identifier)])
        let parser = try MarkdownParser(profile: profile, extensions: [FrontMatter.implementation, Footnotes.implementation],
            collectSyntaxDetails: true).validated()
        let document = parser.parse("---\ntitle: '[^a]'\n---\n# Body\n\nCall[^a]\n\n[^a]: note\n")
        #expect(Footnotes.Index(document).notes.first?.references.count == 1)
        #expect(document.nodes.filter { $0.kind == FrontMatter.kind }.count == 1)
        #expect(document.diagnostics.isEmpty)
        let renderer = FootnotesHTMLRenderer(renderer: HTMLRenderer(hooks: [FrontMatter.kind: { _, _ in .replace("") }]))
        #expect(renderer.render(document).hasPrefix("<h1>Body</h1>\n<p>Call<sup>"))
        #expect(!renderer.render(document).contains("title:"))
    }

    @Test func noteHeadingsParticipateInOutlineWhileNativeAnalysisKeepsCustomContentOpaque() throws {
        let document = Self.parser().parse("# Body\n\nUse[^a]\n\n[^a]: ### Hidden\n\n    trailing \t\n")
        #expect(DocumentIndex(document).outline().map(\.title) == ["Body", "Hidden"])
        #expect(try NativeAnalyzer.analyze(document,
            configuration: NativeAnalysisConfiguration(rules: Set(NativeRule.allCases))).findings.isEmpty)
    }

    @Test func maximumLengthUnicodeLabelsRemainBoundedAndAddressable() {
        for label in [String(repeating: "a", count: 999), String(repeating: "😀", count: 999)] {
            let document = Self.parser().parse("Call[^\(label)]\n\n[^\(label)]: note\n")
            #expect(Footnotes.Index(document).notes.count == 1)
            #expect(document.diagnostics.isEmpty)
        }
    }

    @Test func manyCallsAndNestedDefinitionsRespectResourceLimits() {
        let source = String(repeating: "call[^a] ", count: 1_000) + "\n\n[^a]: note\n"
        let document = Self.parser().parse(source)
        #expect(Footnotes.Index(document).notes.first?.references.count == 1_000)
        #expect(document.diagnostics.isEmpty)
        let nested = Self.parser().parse("use[^a]\n[^a]: Outer\n    [^b]: Inner\n\nuse[^b]\n")
        #expect(Footnotes.Index(nested).notes.count == 2)
        #expect(nested.diagnostics.isEmpty)
        #expect(Self.renderer.render(nested).contains("<p>Inner</p>"))
        let profile = Profile(name: "limited", extensions: [ExtensionConfiguration(Footnotes.identifier)])
        let limited = MarkdownParser(profile: profile, extensions: [Footnotes.implementation],
            limits: ParserLimits(maximumContainerDepth: 4)).parse(
                "use[^a]\n[^a]: A\n    [^b]: B\n        [^c]: C\n            [^d]: D\n                [^e]: E\n")
        #expect(limited.diagnostics.contains { if case .nestingLimitExceeded = $0.code { true } else { false } })
        #expect(Self.renderer.render(limited).contains("footnotes"))
    }
}
