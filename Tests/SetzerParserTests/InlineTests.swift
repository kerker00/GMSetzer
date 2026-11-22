import GMSetzer
import Testing

struct InlineTests {
    func render(_ source: String) -> String { HTMLRenderer.conformance.render(MarkdownParser().parse(source)) }

    @Test func deepEmphasisTokensKeepExactOwnerOrderAcrossLeaves() {
        let run = String(repeating: "*", count: 512)
        let source = run + "x" + run + "\n\n" + run + "y" + run + "\n"
        let annotated = MarkdownParser(collectSyntaxDetails: true).parse(source)
        let plain = MarkdownParser().parse(source)
        let expected = annotated.nodes.enumerated().flatMap { index, node -> [SyntaxToken] in
            guard node.kind == .strong else { return [] }
            return [SyntaxToken("core.emphasis.open", range: SourceRange(node.range.lowerBound, node.range.lowerBound + 2), owner: index),
                    SyntaxToken("core.emphasis.close", range: SourceRange(node.range.upperBound - 2, node.range.upperBound), owner: index)]
        }
        #expect(expected.count == 1_024)
        #expect(annotated.tokens?.filter { $0.role.hasPrefix("core.emphasis.") } == expected)
        #expect(annotated.nodes == plain.nodes && annotated.diagnostics == plain.diagnostics)
        #expect(plain.tokens == nil)
        #expect(HTMLRenderer.conformance.render(annotated) == HTMLRenderer.conformance.render(plain))
    }

    @Test func escapesEntitiesAndCodeAreDecodedOnlyInTheirOwnContexts() {
        #expect(render(#"\* &amp; &#x1F600; &NotEqualTilde; `\* &amp;`"#) == "<p>* &amp; 😀 ≂̸ <code>\\* &amp;amp;</code></p>\n")
        #expect(render(#"\&amp; &amp;amp; &#0; &#xD800; &#1114112; &#12345678; &#x1234567;"#)
            == "<p>&amp;amp; &amp;amp; � � � &amp;#12345678; &amp;#x1234567;</p>\n")
        #expect(render("```a&amp;b\n&amp;\n```\n") == "<pre><code class=\"language-a&amp;b\">&amp;amp;\n</code></pre>\n")
        #expect(render("a\t  \nb") == "<p>a<br />\nb</p>\n")
        #expect(render("    chunk1\n      \n      chunk2\n") == "<pre><code>chunk1\n  \n  chunk2\n</code></pre>\n")
    }

    @Test func sourceRangesPreserveEmojiPrefixesCRLFAndOriginalDelimiters() {
        let source = "> 😀 **a\r\n> b** &amp; ` x `  \r\n> c\n"
        let document = MarkdownParser(collectSyntaxDetails: true).parse(source)
        let strong = document.nodes.first { $0.kind == .strong }!
        #expect(strong.range == SourceRange(7, 17))
        #expect(strong.sourceSegments == [SourceRange(7, 12), SourceRange(14, 17)])
        func spellings(_ role: String) -> [String] {
            (document.tokens ?? []).filter { $0.role == role }.map {
                String(decoding: document.source[$0.range.lowerBound..<$0.range.upperBound], as: UTF8.self)
            }
        }
        #expect(spellings("core.emphasis.open") == ["**"])
        #expect(spellings("core.emphasis.close") == ["**"])
        #expect(spellings("core.entity") == ["&amp;"])
        #expect(spellings("core.code.content") == [" x "])
        #expect(spellings("core.break") == ["  \r\n"])
        #expect(HTMLRenderer.conformance.render(document) == "<blockquote>\n<p>😀 <strong>a\nb</strong> &amp; <code>x</code><br />\nc</p>\n</blockquote>\n")
        let plain = MarkdownParser().parse(source)
        #expect(plain.tokens == nil)
        #expect(plain.nodes == document.nodes)
    }

    @Test func referencesUseUnicodeFoldingSourceSpellingAndFirstDefinition() {
        #expect(render("[STRASSE] [ẞ] [Σ] [foo\\*] [foo*]\n\n[Straße]: /first\n[STRASSE]: /second\n[ss]: /ss\n[ς]: /sigma\n[foo\\*]: /escaped\n")
            == "<p><a href=\"/first\">STRASSE</a> <a href=\"/ss\">ẞ</a> <a href=\"/sigma\">Σ</a> <a href=\"/escaped\">foo*</a> [foo*]</p>\n")
        #expect(render("[a&amp;b] [a&b]\n\n[a&amp;b]: /a&amp;b 'c&amp;d'\n")
            == "<p><a href=\"/a&amp;b\" title=\"c&amp;d\">a&amp;b</a> [a&amp;b]</p>\n")
    }

    @Test func NULReplacementAppliesToReferenceLabelsAndURLSyntax() {
        #expect(render("[a\u{0}]: /u\n\n[a\u{0}]\n") == "<p><a href=\"/u\">a�</a></p>\n")
        #expect(render("[a](x\u{0}y)") == "<p><a href=\"x%EF%BF%BDy\">a</a></p>\n")
        #expect(render("<https://x\u{0}y>") == "<p><a href=\"https://x%EF%BF%BDy\">https://x�y</a></p>\n")
    }

    @Test func linksKeepProtectedDestinationsAndPreciseEmptyComponents() {
        let document = MarkdownParser(collectSyntaxDetails: true).parse("[**x**](<> \"\") ![a *b* `c`](img)\n")
        #expect(HTMLRenderer.conformance.render(document) == "<p><a href=\"\"><strong>x</strong></a> <img src=\"img\" alt=\"a b c\" /></p>\n")
        let destination = document.tokens!.first { $0.role == "core.link.destination" }!
        let title = document.tokens!.first { $0.role == "core.link.title" }!
        #expect(destination.range.isEmpty)
        #expect(title.range.isEmpty)
        #expect(render("[x](a*b) `*x*` *y*\n") == "<p><a href=\"a*b\">x</a> <code>*x*</code> <em>y</em></p>\n")
    }

    @Test func safeRenderingChecksDecodedURLsAndDoesNotTrustRawHTMLPermission() {
        let parser = MarkdownParser()
        for source in ["[x](javascript:alert%281%29)", "[x](JaVaScRiPt:alert%281%29)",
                       "[x](jav&#x61;script:alert%281%29)", "[x](java&#x09;script:alert%281%29)",
                       "![x](data:image/svg+xml,evil)", "[x](vbscript:evil)"] {
            let document = parser.parse(source)
            let expected = source.first == "!" ? "<p><img src=\"\" alt=\"x\" /></p>\n" : "<p><a href=\"\">x</a></p>\n"
            #expect(HTMLRenderer().render(document) == expected)
            #expect(HTMLRenderer(allowRawHTML: true).render(document) == expected)
        }
        #expect(HTMLRenderer().render(parser.parse("[x](https://example.org/ä?q=a&b)\n")) == "<p><a href=\"https://example.org/%C3%A4?q=a&amp;b\">x</a></p>\n")
    }

    @Test func fenceTokensRetainOriginalSpellingAndEmptyInfo() {
        let source = ">  ``` a&amp;b\r\n> x\r\n>  ````\r\n"
        let document = MarkdownParser(collectSyntaxDetails: true).parse(source)
        let tokens = document.tokens!.filter { $0.role.hasPrefix("core.fence.") }
        #expect(tokens.map(\.role) == ["core.fence.open", "core.fence.info", "core.fence.close"])
        #expect(tokens.map { String(decoding: document.source[$0.range.lowerBound..<$0.range.upperBound], as: UTF8.self) } == ["```", "a&amp;b", "````"])
        let empty = MarkdownParser(collectSyntaxDetails: true).parse("```\nx")
        #expect(empty.tokens!.first { $0.role == "core.fence.info" }!.range.isEmpty)
        #expect(!empty.tokens!.contains { $0.role == "core.fence.close" })
    }

    @Test func legalLiteralFallbacksDoNotProduceDocumentErrors() {
        for source in ["*unfinished", "[unknown]", "[x](unfinished", "`unclosed", "~~~\nunfinished\n"] {
            let document = MarkdownParser().parse(source)
            #expect(document.diagnostics.isEmpty)
            #expect(document.source == Array(source.utf8))
        }
    }

    @Test func longRunsAndManyFailedOpenersRemainBounded() {
        for source in [String(repeating: "*", count: 8_192) + "x" + String(repeating: "*", count: 8_192),
                       String(repeating: "[a", count: 4_096) + String(repeating: "]", count: 4_096),
                       (1...512).map { String(repeating: "`", count: $0) + "x" }.joined(),
                       String(repeating: "<!-- x ", count: 4_096)] {
            let document = MarkdownParser().parse(source)
            #expect(document.source.count == source.utf8.count)
            #expect(!HTMLRenderer(preserveHTMLComments: true).render(document).isEmpty)
        }
    }
}

extension InlineTests {
    @Test func UnicodeWhitespaceMatchesTheSpecificationClass() {
        for scalar in ["\u{000B}", "\u{0085}", "\u{2028}", "\u{2029}"] {
            #expect(render("*\(scalar)x*") == "<p><em>\(scalar)x</em></p>\n")
        }
        for scalar in ["\u{000C}", "\u{00A0}", "\u{2003}"] {
            #expect(render("*\(scalar)x*") == "<p>*\(scalar)x*</p>\n")
        }
        #expect(render("[\u{10D50}]\n\n[\u{10D70}]: /garay\n") == "<p><a href=\"/garay\">\u{10D50}</a></p>\n")
    }

    @Test func autolinksDeactivateOuterLinksAndDeclarationsFollow0312() {
        #expect(render("[x <https://example.org>](u)") == "<p>[x <a href=\"https://example.org\">https://example.org</a>](u)</p>\n")
        #expect(render("![x <https://example.org>](u)") == "<p><img src=\"u\" alt=\"x https://example.org\" /></p>\n")
        #expect(render("x <!A> <!a+stuff>") == "<p>x <!A> <!a+stuff></p>\n")
    }

    @Test func controllerReuseKeepsCodeAndDelimiterStateLocalToEachLeaf() {
        #expect(render("`unclosed\n\nclosed`\n\n*a\n\nb*\n\nx <!-- unclosed\n\nx <!--closed-->\n")
            == "<p>`unclosed</p>\n<p>closed`</p>\n<p>*a</p>\n<p>b*</p>\n<p>x &lt;!-- unclosed</p>\n<p>x <!--closed--></p>\n")
    }
}

extension InlineTests {
    @Test func labelMatchingDoesNotApplyCanonicalNormalizationOrUnicodeSpaceCollapse() {
        #expect(render("[é] [e\u{0301}]\n\n[é]: /composed\n[e\u{0301}]: /decomposed\n")
            == "<p><a href=\"/composed\">é</a> <a href=\"/decomposed\">e\u{0301}</a></p>\n")
        #expect(render("[a b] [a\u{00A0}b] [\u{00A0}]\n\n[a\u{00A0}b]: /nbsp\n[\u{00A0}]: /empty-looking\n")
            == "<p>[a b] <a href=\"/nbsp\">a\u{00A0}b</a> <a href=\"/empty-looking\">\u{00A0}</a></p>\n")
    }
}
