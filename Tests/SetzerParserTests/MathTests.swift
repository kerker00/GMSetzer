import GMSetzer
import Testing

struct MathTests {
    static func parser(base: Profile = .commonMark, disabled: Set<String> = [], collect: Bool = true) -> MarkdownParser {
        MarkdownParser(profile: Profile(name: "math-test",
            extensions: base.extensions + [ExtensionConfiguration(Math.identifier)],
            disabledRules: base.disabledRules.union(disabled), ruleOrder: base.ruleOrder),
            extensions: [Math.implementation], collectSyntaxDetails: collect)
    }
    static func expressions(_ document: Document) -> [Math] {
        document.nodes.indices.compactMap { Math(document, at: $0) }
    }

    @Test func inlineTeXIsOpaqueAndPreservesOriginalSpelling() throws {
        let source = #"Math $\alpha_1 *x* &amp; `code` [a](url)$ end."# + "\n"
        let document = try Self.parser().validated().parse(source)
        let math = try #require(Self.expressions(document).first)
        #expect(math.format == .inline && !math.isDisplay)
        #expect(math.tex == #"\alpha_1 *x* &amp; `code` [a](url)"#)
        #expect(math.rawBytes == Array(math.tex.utf8))
        #expect(document.nodes.filter { [.emphasis, .code, .link].contains($0.kind) }.isEmpty)
        #expect(document.source == Array(source.utf8))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func whitespaceAndCurrencyDoNotAccidentallyBecomeInlineMath() {
        for source in ["$20,000 and $30,000", "$ a$", "$a $", "$a$2", "$\tb$", "$a\t$",
                       "$\u{00A0}a$", "$a\u{2003}$", "$a\nb$", "$a\r\nb$", "$a\rb$", "$$", "$$$$", "text $$a$$ end"] {
            let document = Self.parser().parse(source)
            #expect(Self.expressions(document).isEmpty, "\(source)")
            #expect(HTMLRenderer().render(document) == HTMLRenderer().render(MarkdownParser().parse(source)), "\(source)")
            #expect(document.diagnostics.isEmpty)
        }
        #expect(Self.expressions(Self.parser().parse("$20$ and $x$.")).map(\.tex) == ["20", "x"])
    }

    @Test func escapedDollarsAndBackslashParityAreRespected() {
        let source = #"\$no$ then $a\$b$ and \\$c$."#
        let document = Self.parser().parse(source)
        #expect(Self.expressions(document).map(\.tex) == [#"a\$b"#, "c"])
        #expect(document.diagnostics.isEmpty)
        #expect(Self.expressions(Self.parser().parse(#"$a\\$"#)).first?.tex == #"a\\"#)
    }

    @Test func codeHTMLDestinationsTitlesAndReferenceDefinitionsRemainProtected() {
        let source = #"`$code$` \$escaped [link](path$a$b "title $c$") ![alt](path$d$) <i title='$e$'>"#
            + "\n\n```\n$f$\n```\n\n    $g$\n\n[ref]: /$h$ \"$i$\"\n"
        let document = Self.parser().parse(source)
        #expect(Self.expressions(document).isEmpty)
        #expect(document.diagnostics.isEmpty)
    }

    @Test func dollarsInProtectedCodeDoNotStealSubsequentPairs() {
        let source = "`$` $x$ and `$a` $y$ <i title='$'> $z$\n"
        let document = Self.parser().parse(source)
        #expect(Self.expressions(document).map(\.tex) == ["x", "y", "z"])
    }

    @Test func inlineMathKeepsEmphasisAndLinkLabelContext() {
        let document = Self.parser().parse("*$a_b$* [value $x$](url) ![value $y$](image)\n")
        #expect(Self.expressions(document).map(\.tex) == ["a_b", "x", "y"])
        #expect(document.nodes.filter { $0.kind == .emphasis }.count == 1)
        #expect(document.nodes.filter { $0.kind == .link }.count == 1)
        #expect(document.nodes.filter { $0.kind == .image }.count == 1)
        #expect(document.diagnostics.isEmpty)
    }

    @Test func oneLineDisplayBlocksPreserveWhitespaceAndResumeBody() throws {
        let source = "  $$ x_1 + y $$ \t\n# Body\n"
        let document = Self.parser().parse(source)
        let math = try #require(Self.expressions(document).first)
        #expect(math.format == .display && math.isDisplay)
        #expect(math.tex == " x_1 + y ")
        #expect(math.rawBytes == Array(math.tex.utf8))
        #expect(math.contentRanges == [SourceRange(4, 13)])
        #expect(math.range == SourceRange(0, 18))
        #expect(document.nodes.contains { $0.kind == .heading })
        #expect(document.diagnostics.isEmpty)
    }

    @Test func multilineDisplayKeepsOpaqueTeXAndExactProjectedCRLFSegments() throws {
        let source = "> $$\r\n> \\begin{aligned}\r\n> a_b &amp; *x*\r\n> \\end{aligned}\r\n> $$\r\n\r\nBody\n"
        let document = Self.parser().parse(source)
        let math = try #require(Self.expressions(document).first)
        #expect(math.tex == "\\begin{aligned}\na_b &amp; *x*\n\\end{aligned}\n")
        #expect(String(decoding: math.rawBytes, as: UTF8.self) == "\\begin{aligned}\r\na_b &amp; *x*\r\n\\end{aligned}\r\n")
        #expect(math.contentRanges.count == 3)
        #expect(document.nodes.filter { $0.kind == .emphasis }.isEmpty)
        #expect(document.diagnostics.isEmpty)
        #expect(HTMLRenderer().render(document).contains("<p>Body</p>"))
    }

    @Test func displaySupportsEmptyBodiesLineEndingsAndClosingAtEOF() throws {
        for ending in ["\n", "\r\n", "\r"] {
            let document = Self.parser().parse("$$" + ending + "$$")
            let math = try #require(Self.expressions(document).first)
            #expect(math.tex.isEmpty && math.rawBytes.isEmpty)
            #expect(math.contentRanges == [SourceRange(2 + ending.utf8.count, 2 + ending.utf8.count)])
            #expect(document.tokens?.contains { $0.role == "math.content" && $0.range.isEmpty } == true)
            #expect(document.diagnostics.isEmpty)
        }
    }

    @Test func unmatchedAndWrongWidthDisplayFencesFallBackNormally() {
        for source in ["$$\na_b *x*\n", "$$\nx\n$$$\n", "$$$\nx\n$$$\n",
                       "$$$$x$$$$\n", "    $$x$$\n", "$$ x\\$$\n", "$$ x $$$\n"] {
            let document = Self.parser().parse(source)
            #expect(Self.expressions(document).isEmpty, "\(source)")
            #expect(HTMLRenderer().render(document) == HTMLRenderer().render(MarkdownParser().parse(source)), "\(source)")
            #expect(document.source == Array(source.utf8))
            #expect(document.diagnostics.isEmpty)
        }
    }

    @Test func displayCannotConsumeAcrossEnclosingContainerBoundaries() {
        let source = "> $$\n> inside\noutside\n\n$$x$$\n"
        let document = Self.parser().parse(source)
        #expect(Self.expressions(document).map(\.tex) == ["x"])
        #expect(HTMLRenderer().render(document).contains("outside"))
        #expect(document.diagnostics.isEmpty)
        let list = Self.parser().parse("- $$\n  x\n  $$\n- second\n")
        #expect(Self.expressions(list).map(\.tex) == ["x\n"])
        #expect(list.nodes.filter { $0.kind == .listItem }.count == 2)
        #expect(list.diagnostics.isEmpty)
    }

    @Test func displayIndentationAndPartialTabsKeepSemanticAndRawFormsDistinct() throws {
        let document = Self.parser().parse("   $$\n\tx\n   $$\n")
        let math = try #require(Self.expressions(document).first)
        #expect(math.tex == " x\n")
        #expect(math.rawBytes == Array("\tx\n".utf8))
        #expect(document.diagnostics.isEmpty)
    }

    @Test func mathCodeFencesReuseCoreGrammarAndNormalization() throws {
        for fence in ["```", "~~~~"] {
            let document = Self.parser().parse(fence + "math title\r\nx_1 &amp; *raw*\r\n" + fence + "\r\n")
            let math = try #require(Self.expressions(document).first)
            #expect(math.format == .fenced && math.isDisplay)
            #expect(math.tex == "x_1 &amp; *raw*\n")
            #expect(math.rawBytes == Array("x_1 &amp; *raw*\r\n".utf8))
            #expect(document.nodes.filter { $0.kind == .emphasis }.isEmpty)
            #expect(document.diagnostics.isEmpty)
            for role in ["math.fence.open", "math.fence.info", "math.fence.close", "math.content"] {
                #expect(document.tokens?.contains { $0.role == role } == true)
            }
            #expect(document.tokens?.contains { $0.role == "core.fence.open" } == true)
        }
    }

    @Test func fencedMathUsesDecodedLanguageAndLeavesOtherCodeLanguagesAlone() {
        let document = Self.parser().parse("```m&#97;th\nx\n```\n\n```Math\nx\n```\n\n```mathematics\nx\n```\n")
        #expect(Self.expressions(document).map(\.tex) == ["x\n"])
        #expect(document.nodes.filter { $0.kind == .codeBlock }.count == 2)
        #expect(document.diagnostics.isEmpty)
    }

    @Test func emptyAndUnclosedMathCodeFencesFollowCoreEOFPolicy() throws {
        for source in ["```math", "```math\n```\n"] {
            let document = Self.parser().parse(source)
            let math = try #require(Self.expressions(document).first)
            #expect(math.format == .fenced && math.tex.isEmpty && math.rawBytes.isEmpty)
            #expect(math.contentRanges.count == 1 && math.contentRanges[0].isEmpty)
            #expect(document.diagnostics.isEmpty)
        }
        let unclosed = Self.parser().parse("```math\nx")
        #expect(Self.expressions(unclosed).first?.tex == "x\n")
        #expect(Self.expressions(unclosed).first?.rawBytes == Array("x".utf8))
    }

    @Test func modesAreIndependentlyDisabledAndStrictProfilesRemainUnselected() throws {
        let source = "Text $a$\n\n$$b$$\n\n```math\nc\n```\n"
        for (disabled, absent): (String, Math.Format) in [("math.inline", .inline), ("math.display", .display), ("math.fenced", .fenced)] {
            let document = try Self.parser(disabled: [disabled]).validated().parse(source)
            #expect(!Self.expressions(document).contains { $0.format == absent })
            #expect(Self.expressions(document).count == 2)
            #expect(document.diagnostics.isEmpty)
        }
        for profile in [Profile.commonMark, .gfm] {
            let plain = MarkdownParser(profile: profile, collectSyntaxDetails: true).parse(source)
            let supplied = MarkdownParser(profile: profile, extensions: [Math.implementation], collectSyntaxDetails: true).parse(source)
            #expect(plain.nodes == supplied.nodes && plain.tokens == supplied.tokens)
            #expect(Self.expressions(supplied).isEmpty)
        }
    }

    @Test func annotationsOffPreserveAllFormatsAndExactOwnerRanges() {
        let source = "Text $Ä😀$\n\n$$\nx\n$$\n\n```math\ny\n```\n"
        let on = Self.parser().parse(source), off = Self.parser(collect: false).parse(source)
        #expect(on.nodes == off.nodes && on.diagnostics == off.diagnostics)
        #expect(on.customLeafFallbacks == off.customLeafFallbacks)
        #expect(Self.expressions(on) == Self.expressions(off))
        #expect(HTMLRenderer().render(on) == HTMLRenderer().render(off))
        #expect(off.tokens == nil)
        for token in on.tokens ?? [] where token.role.hasPrefix("math.") {
            #expect([Math.inlineKind, Math.blockKind].contains(on.nodes[token.owner].kind))
            #expect(on.nodes[token.owner].range.contains(token.range))
        }
        let inline = (on.tokens ?? []).filter { $0.role.hasPrefix("math.") && on.nodes[$0.owner].kind == Math.inlineKind }
        #expect(inline.map(\.range) == [SourceRange(5, 6), SourceRange(6, 12), SourceRange(12, 13)])
    }

    @Test func BOMInvalidUTF8NULAndUnicodeKeepOriginalBytesInEveryFormat() {
        let raw = Array("Ä😀".utf8) + [255, 0]
        for (prefix, suffix) in [("$", "$"), ("$$\r\n", "\r\n$$"), ("```math\r\n", "\r\n```\r\n")] {
            let bytes = [UInt8(0xEF), 0xBB, 0xBF] + Array(prefix.utf8) + raw + Array(suffix.utf8)
            let document = Self.parser().parse(bytes: bytes)
            #expect(document.source == bytes)
            let math = Self.expressions(document).first
            #expect(math != nil)
            #expect(math?.rawBytes.starts(with: raw) == true)
            #expect(math?.tex.contains("Ä😀��") == true)
            #expect(math?.tex.utf8.contains(0) == false)
            #expect(document.diagnostics.isEmpty)
        }
    }

    @Test func typedViewRejectsOtherNodesBadIndicesAndMalformedPayloads() throws {
        let plain = MarkdownParser().parse("body\n")
        #expect(Math(plain, at: -1) == nil && Math(plain, at: plain.nodes.count) == nil)
        #expect(Math(plain, at: 1) == nil)
        var builder = DocumentBuilder(source: Array("$x$".utf8))
        let paragraph = try builder.append(.paragraph, range: SourceRange(0, 3))
        let wrong = try builder.append(.custom(kind: Math.inlineKind, role: .inline,
            attributes: ["format": .string("unknown"), "tex": .string("x")]), range: SourceRange(0, 3), to: paragraph)
        #expect(Math(try builder.build(), at: wrong) == nil)
    }

    @Test func rendererHooksChoosePresentationAndDefaultFallbackEscapesSource() {
        let document = Self.parser().parse("Text $<script>x</script>$\n\n$$<img src=x>$$\n")
        let fallback = HTMLRenderer(allowRawHTML: true).render(document)
        #expect(!fallback.contains("<script>") && !fallback.contains("<img"))
        let hook: ContextualHTMLRendererHook = { context in
            guard let math = Math(context.tree.document, at: context.index) else { return nil }
            let tag = math.isDisplay ? "div" : "span"
            return .replace("<\(tag) class=\"tex\">\(HTMLRenderer.escape(math.tex))</\(tag)>")
        }
        let html = HTMLRenderer(contextualHooks: [Math.inlineKind: hook, Math.blockKind: hook]).render(document)
        #expect(html.contains("<span class=\"tex\">&lt;script&gt;x&lt;/script&gt;</span>"))
        #expect(html.contains("<div class=\"tex\">&lt;img src=x&gt;</div>"))
    }

    @Test func mathGFMFrontMatterAndFootnotesComposeWithoutInterpretingOpaqueBodies() throws {
        let profile = Profile(name: "combined", extensions: Profile.gfm.extensions +
            [ExtensionConfiguration(FrontMatter.identifier), ExtensionConfiguration(Footnotes.identifier), ExtensionConfiguration(Math.identifier)])
        let parser = try MarkdownParser(profile: profile,
            extensions: [FrontMatter.implementation, Footnotes.implementation, Math.implementation], collectSyntaxDetails: true).validated()
        let document = parser.parse("---\ntitle: '$hidden$'\n---\n| Formula |\n| - |\n| $x$[^a] |\n\n[^a]: $y$\n\n    $$\n    [^a] *z*\n    $$\n")
        #expect(Self.expressions(document).map(\.tex) == ["x", "y", "[^a] *z*\n"])
        #expect(Footnotes.Index(document).notes.first?.references.count == 1)
        #expect(document.diagnostics.isEmpty)
        #expect(FootnotesHTMLRenderer().render(document).contains("<table>"))
    }

    @Test func analysisAndOutlineKeepTheirOpaqueCustomContentPolicy() throws {
        let document = Self.parser().parse("# Body\n\n$$\n### hidden\ntrailing \t\n$$\n\n```math\n# hidden too\n```\n")
        #expect(DocumentIndex(document).outline().map(\.title) == ["Body"])
        #expect(try NativeAnalyzer.analyze(document,
            configuration: NativeAnalysisConfiguration(rules: Set(NativeRule.allCases))).findings.isEmpty)
    }

    @Test func manyUnmatchedCandidatesAndLongDollarRunsRetainInput() {
        let source = String(repeating: "$a$2 ", count: 2_000) + "\n" + String(repeating: "$", count: 10_000) + "\n$$\n" + String(repeating: "plain\n", count: 1_000)
        let document = Self.parser().parse(source)
        #expect(document.source == Array(source.utf8))
        #expect(Self.expressions(document).isEmpty)
        #expect(document.diagnostics.isEmpty)
    }
}
