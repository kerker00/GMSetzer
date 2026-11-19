import GMSetzer
import Testing

struct HTMLBlockTests {
    @Test(arguments: [
        ("<script>\n\ncode\n</STYLE>\nafter\n", HTMLBlockKind.rawText),
        ("<!-- note\n\nend -->\nafter\n", .comment),
        ("<?pi\nend ?>\nafter\n", .processingInstruction),
        ("<!DOCTYPE\nhtml>\nafter\n", .declaration),
        ("<![CDATA[\n\ntext\n]]>\nafter\n", .cdata),
        ("<DIV class=oops\ntext\n\nafter\n", .blockTag),
        ("<custom a='>' bool other=x>\ntext\n\nafter\n", .completeTag),
    ])
    func recognisesAllSevenHTMLBlockClasses(_ fixture: (String, HTMLBlockKind)) {
        let document = MarkdownParser().parse(fixture.0)
        guard case .htmlBlock(let block) = document.nodes[1].data else { Issue.record("Expected an HTML block"); return }
        #expect(block.kind == fixture.1)
        #expect(document.nodes.last?.data == .text("after"))
        #expect(HTMLRenderer(allowRawHTML: true, preserveHTMLComments: true).render(document).hasSuffix("<p>after</p>\n"))
    }

    @Test func typeSevenCannotInterruptParagraphsAndSpecialTagNamesAreExact() {
        let parser = MarkdownParser()
        #expect(parser.parse("text\n<custom>\n").nodes[1].kind == .paragraph)
        #expect(parser.parse("<custom invalid= >\n").nodes[1].kind == .paragraph)
        #expect(parser.parse("<scripture>\n").nodes[1].data == .htmlBlock(HTMLBlock(kind: .completeTag, literal: "<scripture>\n")))
        #expect(parser.parse("<script/>\n").nodes[1].kind == .paragraph)
        #expect(parser.parse("text\n<!-- note -->\n").children(of: 0).count == 2)
    }

    @Test func HTMLStopsAtContainerBoundaryAndRetainsOriginalRanges() {
        let document = MarkdownParser().parse("> <!-- α\r\n> end -->\r\noutside\n")
        let html = document.nodes[2]
        #expect(html.range == SourceRange(2, 22))
        #expect(html.sourceSegments == [SourceRange(2, 11), SourceRange(13, 22)])
        #expect(html.data == .htmlBlock(HTMLBlock(kind: .comment, literal: "<!-- α\nend -->\n")))
        #expect(HTMLRenderer().render(document) == "<blockquote>\n</blockquote>\n<p>outside</p>\n")
        let unclosed = MarkdownParser().parse("> <script>\noutside\n")
        #expect(HTMLRenderer(allowRawHTML: true).render(unclosed) == "<blockquote>\n<script>\n</blockquote>\n<p>outside</p>\n")
    }

    @Test func commentsAreSuppressedOnlyInHTMLContext() {
        let renderer = HTMLRenderer()
        let parser = MarkdownParser()
        #expect(renderer.render(parser.parse("<!-- secret -->\n")) == "")
        #expect(renderer.render(parser.parse("<!-- secret -->visible\n")) == "visible\n")
        #expect(renderer.render(parser.parse("<div title=\"<!-- literal -->\">\n<!-- secret -->\n</div>\n")) ==
                "&lt;div title=&quot;&lt;!-- literal --&gt;&quot;&gt;\n\n&lt;/div&gt;\n")
        #expect(renderer.render(parser.parse("<script>const x = '<!-- literal -->';</script>\n")).contains("&lt;!-- literal --&gt;"))
        #expect(renderer.render(parser.parse("<![CDATA[<!-- literal -->]]>\n")).contains("&lt;!-- literal --&gt;"))
        #expect(renderer.render(parser.parse("```\n<!-- code -->\n```\n")) == "<pre><code>&lt;!-- code --&gt;\n</code></pre>\n")
        #expect(renderer.render(parser.parse("<!-- unclosed\n")) == "")
    }

    @Test func rawHTMLAndCommentPermissionAreSeparate() {
        let document = MarkdownParser().parse("<div>\n<!-- private -->\n</div>\n")
        #expect(HTMLRenderer(allowRawHTML: true).render(document) == "<div>\n\n</div>\n")
        #expect(HTMLRenderer(preserveHTMLComments: true).render(document).contains("&lt;!-- private --&gt;"))
        #expect(HTMLRenderer(allowRawHTML: true, preserveHTMLComments: true).render(document) == "<div>\n<!-- private -->\n</div>\n")
    }
}
