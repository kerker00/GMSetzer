import GMSetzer
import Testing

struct HTMLNormalizationTests {
    @Test func onlyGeneratedVoidTagSlashesAreNormalized() {
        let document = MarkdownParser().parse("a  \nb\n\n---\n\n![x](u)\n")
        let html = HTMLRenderer.conformance.render(document)
        #expect(HTMLNormalization.normalize(html, document: document) == "<p>a<br>\nb</p>\n<hr>\n<p><img src=\"u\" alt=\"x\"></p>\n")
        #expect(HTMLNormalization.normalize("<p>a  \t b</p>\n", document: document) == "<p>a  \t b</p>\n")
        #expect(HTMLNormalization.normalize("<img src=\"a /> b\" alt=\"\" />", document: document) == "<img src=\"a /> b\" alt=\"\">")
    }

    @Test func codeRawHTMLCommentsAndWhitespaceStayExact() {
        let source = "<div>\n<br />  \t\n</div>\n\n`<br />`\n\n```\na  \t<br />\n```\n\n<!-- <hr /> -->\n"
        let document = MarkdownParser().parse(source)
        let html = HTMLRenderer.conformance.render(document)
        #expect(HTMLNormalization.normalize(html, document: document) == html)
        let inline = MarkdownParser().parse("a <br /> b")
        let inlineHTML = HTMLRenderer.conformance.render(inline)
        #expect(HTMLNormalization.normalize(inlineHTML, document: inline) == inlineHTML)
    }
}
