import GMSetzer
import Testing

struct AdmonitionTests {
    static func parser(callouts: Bool = false, both: Bool = false, reverse: Bool = false,
                       base: Profile = .commonMark, disabled: Set<String> = [], collect: Bool = true,
                       order: [String] = []) -> MarkdownParser {
        var implementations = both ? [Alert.implementation, Callout.implementation]
            : [callouts ? Callout.implementation : Alert.implementation]
        if reverse { implementations.reverse() }
        return MarkdownParser(profile: Profile(name: "admonitions", extensions: base.extensions +
            implementations.map { ExtensionConfiguration($0.identifier) }, disabledRules: disabled, ruleOrder: order),
            extensions: implementations, collectSyntaxDetails: collect)
    }
    static let renderer = AdmonitionHTML.renderer()

    @Test func allFiveAlertTypesRetainBodyMarkdownAndGenerateTitles() throws {
        for category in Alert.Category.allCases {
            let document = try Self.parser().validated().parse("> [!\(category.rawValue)]\n> Body *text*.\n")
            let index = try #require(document.nodes.firstIndex { $0.kind == Alert.kind })
            let alert = try #require(Alert(document, at: index))
            #expect(alert.category == category)
            #expect(document.nodes.filter { $0.kind == .paragraph }.count == 1)
            #expect(document.nodes.filter { $0.kind == .emphasis }.count == 1)
            #expect(document.diagnostics.isEmpty)
            let html = Self.renderer.render(document)
            #expect(html.contains("markdown-alert-\(category.rawValue.lowercased())"))
            #expect(html.contains(">\(category.defaultTitle)</p>\n<p>Body <em>text</em>.</p>"))
            #expect(!html.contains("[!"))
        }
    }

    @Test func alertHeadersRequireExactUppercaseTypeOnTheFirstPhysicalQuoteLine() {
        for source in ["> [!note]\n> body\n", "> [!OTHER]\n> body\n", "> [!NOTE] title\n> body\n",
                       "> [!NOTE]+\n> body\n", "> [!NOTE]-\n> body\n", "> words [!NOTE]\n",
                       ">\n> [!NOTE]\n> body\n", "> before\n> [!NOTE]\n", "> \\[!NOTE]\n",
                       "> `[!NOTE]`\n", ">     [!NOTE]\n", "```\n> [!NOTE]\n```\n"] {
            let extended = Self.parser().parse(source)
            let strict = MarkdownParser(collectSyntaxDetails: true).parse(source)
            #expect(extended.nodes == strict.nodes, "\(source)")
            #expect(extended.tokens == strict.tokens)
            #expect(!extended.nodes.contains { $0.kind == Alert.kind })
        }
    }

    @Test func emptyAlertsAndBlankSeparatedBodiesHaveNoPhantomParagraph() throws {
        let empty = Self.parser().parse("> [!NOTE]\n")
        let index = try #require(empty.nodes.firstIndex { $0.kind == Alert.kind })
        #expect(empty.nodes[index].firstChild == nil)
        #expect(empty.customLeafFallbacks[index] == "")
        #expect(HTMLRenderer().render(empty).isEmpty)
        #expect(Self.renderer.render(empty) == "<aside class=\"markdown-alert markdown-alert-note\" role=\"note\">\n<p class=\"markdown-alert-title\">Note</p>\n</aside>\n")
        let separated = Self.parser().parse("> [!NOTE]\n>\n> Body\n")
        #expect(Self.renderer.render(separated).contains("</p>\n<p>Body</p>\n</aside>"))
        #expect(!Self.renderer.render(separated).contains("<p></p>"))
        #expect(separated.diagnostics.isEmpty)
    }

    @Test func alertBodyKeepsMultipleBlocksAndNestedContainers() {
        let document = Self.parser().parse("- > [!TIP]\n  > Intro\n  >\n  > - item\n  >\n  > # Heading\n  >\n  > ```\n  > code\n  > ```\n- next\n")
        #expect(document.nodes.filter { $0.kind == Alert.kind }.count == 1)
        #expect(document.nodes.filter { $0.kind == .list }.count == 2)
        #expect(document.nodes.filter { $0.kind == .codeBlock }.count == 1)
        #expect(DocumentIndex(document).outline().map(\.title) == ["Heading"])
        let html = Self.renderer.render(document)
        #expect(html.contains("<li>item</li>"))
        #expect(html.contains("<li>next</li>"))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func customTitlesAreParsedAsInlineMarkdownWithoutJoiningTheBody() throws {
        let document = try Self.parser(callouts: true).validated().parse("> [!tip] A **bold** [title](https://example.org)\n> Body *text*\n")
        let index = try #require(document.nodes.firstIndex { $0.kind == Callout.kind })
        let callout = try #require(Callout(document, at: index))
        #expect(callout.type == "tip" && callout.style == "tip" && callout.fold == .none)
        #expect(callout.hasCustomTitle && callout.titleNode != nil)
        #expect(callout.title == "A **bold** [title](https://example.org)")
        let html = Self.renderer.render(document)
        #expect(html.contains("<div class=\"callout-title\">A <strong>bold</strong> <a href=\"https://example.org\">title</a></div>"))
        #expect(html.contains("<p>Body <em>text</em></p>"))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func foldingUsesDetailsAndTitleOnlyCalloutsStayValid() throws {
        for (marker, fold) in [("+", Callout.Fold.expanded), ("-", .collapsed), ("", .none)] {
            let document = Self.parser(callouts: true).parse("> [!faq]\(marker) Title only\n")
            let index = try #require(document.nodes.firstIndex { $0.kind == Callout.kind })
            #expect(Callout(document, at: index)?.fold == fold)
            let html = Self.renderer.render(document)
            if fold == .none { #expect(html.hasPrefix("<aside")) }
            else {
                #expect(html.hasPrefix("<details"))
                #expect(html.contains("<summary class=\"callout-title\">Title only</summary>"))
                #expect(html.contains(" open>") == (fold == .expanded))
            }
            #expect(!html.contains("<p>"))
            #expect(document.diagnostics.isEmpty)
        }
    }

    @Test func generatedCalloutTitlesAliasesAndUnknownTypesArePortable() throws {
        for (type, style) in [("NoTe", "note"), ("SUMMARY", "abstract"), ("todo", "todo"),
                              ("hint", "tip"), ("important", "tip"), ("done", "success"),
                              ("faq", "question"), ("attention", "warning"), ("missing", "failure"),
                              ("error", "danger"), ("cite", "quote"), ("custom-type", "note")] {
            let document = Self.parser(callouts: true).parse("> [!\(type)]\n> body\n")
            let index = try #require(document.nodes.firstIndex { $0.kind == Callout.kind })
            let callout = try #require(Callout(document, at: index))
            #expect(callout.type == type.lowercased() && callout.style == style)
            #expect(!callout.hasCustomTitle && callout.titleNode == nil)
            #expect(!callout.title.isEmpty)
            #expect(Self.renderer.render(document).contains("data-callout=\"\(type.lowercased())\""))
            #expect(document.diagnostics.isEmpty)
        }
    }

    @Test func malformedCalloutMarkersRemainOrdinaryQuotes() {
        for source in ["> [!] title\n", "> [!a b] title\n", "> [!a\"b] title\n", "> [!Ä] title\n",
                       "> [!note]++ title\n", "> [!note]title\n", "> text [!note]\n",
                       ">\n> [!note]\n", "> [!note\n"] {
            let document = Self.parser(callouts: true).parse(source)
            let plain = MarkdownParser(collectSyntaxDetails: true).parse(source)
            #expect(document.nodes == plain.nodes, "\(source)")
            #expect(document.tokens == plain.tokens)
        }
    }

    @Test func nestedCalloutsKeepNormalListQuoteSemantics() {
        let document = Self.parser(callouts: true).parse("> [!question] Outer\n> > [!todo]- Inner\n> > - task\n> >\n> > more\n")
        #expect(document.nodes.filter { $0.kind == Callout.kind }.count == 2)
        let html = Self.renderer.render(document)
        #expect(html.contains("<details class=\"callout callout-todo\""))
        #expect(html.contains("<li>task</li>"))
        #expect(html.contains("<p>more</p>"))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func overlappingSelectionUsesRulePrecedenceAndDefaultProfileOrder() throws {
        for reverse in [false, true] {
            let document = try Self.parser(both: true, reverse: reverse).validated().parse("> [!NOTE]\n> body\n")
            #expect(document.nodes.contains { $0.kind == (reverse ? Callout.kind : Alert.kind) })
            #expect(!document.nodes.contains { $0.kind == (reverse ? Alert.kind : Callout.kind) })
            let folding = Self.parser(both: true, reverse: reverse).parse("> [!NOTE]+ Title\n> body\n")
            #expect(folding.nodes.contains { $0.kind == Callout.kind })
            #expect(folding.diagnostics.isEmpty && document.diagnostics.isEmpty)
        }
        let explicit = try Self.parser(both: true, order: ["callouts.recognise", "alerts.recognise"])
            .validated().parse("> [!NOTE]\n> body\n")
        #expect(explicit.nodes.contains { $0.kind == Callout.kind })
        #expect(explicit.diagnostics.isEmpty)
    }

    @Test func ruleDisablingAndUnselectedImplementationsPreserveCoreBehavior() throws {
        let source = "> [!NOTE]\n> body\n"
        for callouts in [false, true] {
            let identifier = callouts ? Callout.identifier : Alert.identifier
            let document = try Self.parser(callouts: callouts, disabled: [identifier + ".recognise"]).validated().parse(source)
            let plain = MarkdownParser(collectSyntaxDetails: true).parse(source)
            #expect(document.nodes == plain.nodes && document.tokens == plain.tokens)
        }
        for profile in [Profile.commonMark, .gfm] {
            let supplied = MarkdownParser(profile: profile, extensions: [Alert.implementation, Callout.implementation], collectSyntaxDetails: true).parse(source)
            let plain = MarkdownParser(profile: profile, collectSyntaxDetails: true).parse(source)
            #expect(supplied.nodes == plain.nodes && supplied.tokens == plain.tokens)
        }
    }

    @Test func exactHeaderAndQuoteTokensSurviveCRLFUnicodeAndTreeReindexing() throws {
        let source = "> [!note]- Ä😀 *title*\r\n> Body\r\n\r\n> ordinary\r\n"
        let document = Self.parser(callouts: true).parse(source)
        let owner = try #require(document.nodes.firstIndex { $0.kind == Callout.kind })
        let header = (document.tokens ?? []).filter { $0.role.hasPrefix("callouts.") }
        #expect(header.map(\.role) == ["callouts.marker.open", "callouts.type", "callouts.marker.close", "callouts.fold", "callouts.title"])
        #expect(header.map { String(decoding: document.source[$0.range.lowerBound..<$0.range.upperBound], as: UTF8.self) }
            == ["[!", "note", "]", "-", "Ä😀 *title*"])
        #expect(header.allSatisfy { $0.owner == owner })
        let quotes = (document.tokens ?? []).filter { $0.role == "core.blockQuote.marker" }
        #expect(quotes.count == 3)
        #expect(quotes.filter { $0.owner == owner }.count == 2)
        #expect(quotes.allSatisfy { document.nodes[$0.owner].range.contains($0.range) })
        #expect(document.tokens?.contains { $0.role == "core.emphasis.open" } == true)
        #expect(document.diagnostics.isEmpty)
    }

    @Test func annotationModesHaveIdenticalTreesViewsAndHTML() {
        let source = "> [!note]- **Title**\n> - *Body*\n\n> [!TIP]\n> Another\n"
        let on = Self.parser(both: true).parse(source), off = Self.parser(both: true, collect: false).parse(source)
        #expect(on.nodes == off.nodes && on.diagnostics == off.diagnostics)
        #expect(on.customLeafFallbacks == off.customLeafFallbacks)
        #expect(Self.renderer.render(on) == Self.renderer.render(off))
        #expect(off.tokens == nil)
        #expect(on.diagnostics.isEmpty)
    }

    @Test func BOMAllLineEndingsMalformedBytesAndNULRetainOriginalSource() throws {
        for ending in ["\n", "\r\n", "\r"] {
            let bytes = [UInt8(0xEF), 0xBB, 0xBF] + Array("> [!note] Ä".utf8) + [255, 0] + Array((ending + "> body" + ending).utf8)
            let document = Self.parser(callouts: true).parse(bytes: bytes)
            let index = try #require(document.nodes.firstIndex { $0.kind == Callout.kind })
            #expect(Callout(document, at: index)?.title == "Ä��")
            #expect(document.source == bytes && document.diagnostics.isEmpty)
            #expect(!Self.renderer.render(document).utf8.contains(0))
        }
    }

    @Test func sourceAnchorsLocalizedTitlesAndExistingHooksArePreserved() {
        let document = Self.parser(both: true).parse("> [!NOTE]\n> *Body*\n\n> [!custom-type]\n> Other\n")
        let base = HTMLRenderer(includeSourceRanges: true, sourceAnchorPrefix: "s-",
            hooks: [.emphasis: { _, _ in .wrapChildren(open: "<i>", close: "</i>") }])
        let renderer = AdmonitionHTML.renderer(base, alertTitles: [.note: "Hinweis <&"], calloutTitles: ["custom-type": "Custom <&"])
        let html = renderer.render(document)
        #expect(html.contains("Hinweis &lt;&amp;"))
        #expect(html.contains("Custom &lt;&amp;"))
        #expect(html.contains("<i>Body</i>"))
        #expect(html.contains("id=\"s-1\" data-source-start=\"0\""))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func titleHTMLAndURLsStayUnderTheBaseRenderersSafetyPolicy() {
        let document = Self.parser(callouts: true, base: .gfm).parse("> [!note]- <script>bad</script> [bad](javascript:alert(1))\n> body\n")
        let safe = Self.renderer.render(document)
        #expect(!safe.contains("<script>") && safe.contains("&lt;script&gt;"))
        #expect(safe.contains("href=\"\""))
        let allowed = AdmonitionHTML.renderer(HTMLRenderer(allowRawHTML: true)).render(document)
        #expect(!allowed.contains("<script>"))
        #expect(document.renderingPolicy.contains(.filtersDisallowedRawHTML))
    }

    @Test func allM5FeaturesComposeIncludingMathAndFootnoteCallsInTheTitle() throws {
        let profile = Profile(name: "all", extensions: Profile.gfm.extensions +
            [Alert.identifier, Callout.identifier, FrontMatter.identifier, Footnotes.identifier, Math.identifier].map { ExtensionConfiguration($0) })
        let parser = try MarkdownParser(profile: profile,
            extensions: [Alert.implementation, Callout.implementation, FrontMatter.implementation, Footnotes.implementation, Math.implementation],
            collectSyntaxDetails: true).validated()
        let document = parser.parse("---\ntitle: '> [!NOTE]'\n---\n> [!note]- Title $x$[^a]\n> Body\n\n[^a]: note\n\n    > [!WARNING]\n    > inside note\n")
        let mathHook: ContextualHTMLRendererHook = { context in
            guard let math = Math(context.tree.document, at: context.index) else { return nil }
            return .replace("<span class=\"math\">\(HTMLRenderer.escape(math.tex))</span>")
        }
        let base = HTMLRenderer(hooks: [FrontMatter.kind: { _, _ in .replace("") }], contextualHooks: [Math.inlineKind: mathHook])
        let html = FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(base)).render(document)
        #expect(html.contains("<summary class=\"callout-title\">Title <span class=\"math\">x</span><sup><a href=\"#fn-note-1\""))
        #expect(html.contains("markdown-alert-warning"))
        #expect(html.contains("href=\"#fn-ref-1-1\""))
        #expect(Footnotes.Index(document).notes.first?.references.count == 1)
        #expect(document.diagnostics.isEmpty)
    }

    @Test func metadataCodeAndOrdinaryQuotesDoNotInventAdmonitions() {
        let source = "```\n> [!note]- title\n```\n\n> ordinary\n\n    > [!NOTE]\n"
        let document = Self.parser(both: true).parse(source)
        #expect(!document.nodes.contains { [Alert.kind, Callout.kind].contains($0.kind) })
        #expect(document.nodes == MarkdownParser().parse(source).nodes)
    }

    @Test func typedViewsRejectWrongIndicesKindsAndPayloads() throws {
        let plain = MarkdownParser().parse("body")
        #expect(Alert(plain, at: -1) == nil && Callout(plain, at: plain.nodes.count) == nil)
        #expect(Alert(plain, at: 1) == nil && Callout(plain, at: 1) == nil)
        var builder = DocumentBuilder(source: [])
        let bad = try builder.append(.custom(kind: Callout.kind, role: .block,
            attributes: ["type": .string("bad\"type"), "fold": .string("unknown")]), range: SourceRange(0, 0))
        #expect(Callout(try builder.build(), at: bad) == nil)
    }

    @Test func outlineIncludesBodyHeadingsWhileNativeAnalysisKeepsCustomBodiesOpaque() throws {
        let document = Self.parser(callouts: true).parse("# Visible\n\n> [!note] Title\n>\n> ### Body heading\n>\n> trailing \t\n")
        #expect(DocumentIndex(document).outline().map(\.title) == ["Visible", "Body heading"])
        #expect(try NativeAnalyzer.analyze(document,
            configuration: NativeAnalysisConfiguration(rules: Set(NativeRule.allCases))).findings.isEmpty)
    }

    @Test func bodySeparatorsAndTablesCannotConsumeTheHeaderAsSetextOrHeaderCells() {
        for callouts in [false, true] {
            let document = Self.parser(callouts: callouts, base: .gfm).parse("> [!NOTE]\n> ---\n>\n> | a |\n> | - |\n> | b |\n")
            #expect(document.nodes.contains { $0.kind == (callouts ? Callout.kind : Alert.kind) })
            #expect(document.nodes.filter { $0.kind == .thematicBreak }.count == 1)
            #expect(document.nodes.filter { $0.kind == .table }.count == 1)
            #expect(!document.nodes.contains { $0.kind == .heading })
            #expect(document.diagnostics.isEmpty)
            #expect(Self.renderer.render(document).contains("<hr />\n<table>"))
        }
    }

    @Test func headerIndentationAndPartialTabPrefixesStayInsideQuotes() {
        for source in ["> [!note]\n> body\n", ">\t[!note]\n> body\n", ">    [!note]\n> body\n",
                       "- > [!note]\n  > body\n"] {
            let document = Self.parser(callouts: true).parse(source)
            #expect(document.nodes.filter { $0.kind == Callout.kind }.count == 1, "\(source)")
            #expect(document.source == Array(source.utf8) && document.diagnostics.isEmpty)
        }
        let outside = Self.parser(callouts: true).parse("[!note]\nbody\n")
        #expect(!outside.nodes.contains { $0.kind == Callout.kind })
    }

    @Test func manyCalloutsAndNestedContainersRemainFinite() {
        let source = String(repeating: "> [!note]- Title\n> Body\n\n", count: 300)
        let document = Self.parser(callouts: true).parse(source)
        #expect(document.nodes.filter { $0.kind == Callout.kind }.count == 300)
        #expect(document.source == Array(source.utf8) && document.diagnostics.isEmpty)
        #expect(Self.renderer.render(document).split(separator: "\n").filter { $0.hasPrefix("<details") }.count == 300)
    }
}
