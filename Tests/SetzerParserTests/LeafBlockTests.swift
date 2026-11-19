import GMSetzer
import Testing

struct LeafBlockTests {
    @Test func headingsAndParagraphsHaveExactOriginalByteRanges() {
        let text = "# Grüße 😀\r\n\r\n  A & B\rnext\n"
        let document = MarkdownParser().parse(text)
        let blocks = document.children(of: 0).map { document.nodes[$0] }
        #expect(blocks.count == 2)
        #expect(blocks[0].data == .heading(level: 1))
        #expect(blocks[0].range == SourceRange(0, 16))
        #expect(blocks[0].sourceSegments == [SourceRange(2, 14)])
        #expect(blocks[1].range == SourceRange(18, 31))
        #expect(HTMLRenderer().render(document) == "<h1>Grüße 😀</h1>\n<p>A &amp; B\nnext</p>\n")
        let breaks = document.nodes.filter { $0.kind == .softBreak }
        #expect(breaks.map(\.range) == [SourceRange(25, 26)])
    }

    @Test(arguments: [
        ("### title ###  \n", "<h3>title</h3>\n"),
        ("### ###\n", "<h3></h3>\n"),
        ("# title#\n", "<h1>title#</h1>\n"),
        ("# title \\#\n", "<h1>title \\#</h1>\n"),
        ("####### title\n", "<p>####### title</p>\n"),
        ("#title\n", "<p>#title</p>\n"),
        ("one\ntwo\n===\n", "<h1>one\ntwo</h1>\n"),
        ("one\n---\n", "<h2>one</h2>\n"),
        ("one\n\n---\n", "<p>one</p>\n<hr />\n"),
        ("---\n", "<hr />\n"),
        ("a\n* * *\nb\n", "<p>a</p>\n<hr />\n<p>b</p>\n"),
        ("a\n    b\n", "<p>a\nb</p>\n"),
    ])
    func blockPrecedenceAndHeadingDelimiters(_ fixture: (String, String)) {
        #expect(HTMLRenderer().render(MarkdownParser().parse(fixture.0)) == fixture.1)
    }

    @Test(arguments: [
        ("```swift\n<&>\n```\n", "<pre><code class=\"language-swift\">&lt;&amp;&gt;\n</code></pre>\n"),
        ("~~~\nlast", "<pre><code>last\n</code></pre>\n"),
        ("```\n```\n", "<pre><code></code></pre>\n"),
        ("````\n```\n`````\n", "<pre><code>```\n</code></pre>\n"),
        ("  ```\n\tx\n  ```\n", "<pre><code>  x\n</code></pre>\n"),
        ("    first\n\n    second\n\nend\n", "<pre><code>first\n\nsecond\n</code></pre>\n<p>end</p>\n"),
        ("\tcode\r\n", "<pre><code>code\n</code></pre>\n"),
    ])
    func codeBlocksPreserveLiteralTextAndNormaliseLineEndings(_ fixture: (String, String)) {
        #expect(HTMLRenderer().render(MarkdownParser().parse(fixture.0)) == fixture.1)
    }

    @Test func codeBlockSegmentsExcludeFencesAndRemovedIndentation() {
        let document = MarkdownParser().parse("  ```txt\r\n  a\r\n  ```\r\n")
        let code = document.nodes[1]
        #expect(code.data == .codeBlock(info: "txt", literal: "a\n"))
        #expect(code.range == SourceRange(0, document.source.count))
        #expect(code.sourceSegments == [SourceRange(12, 15)])
    }

    @Test func invalidUTF8AndNULKeepOriginalSourceOffsets() {
        let bytes: [UInt8] = [35, 32, 0xFF, 0, 13, 10]
        let document = MarkdownParser().parse(bytes: bytes)
        #expect(document.source == bytes)
        #expect(document.nodes[1].range == SourceRange(0, 6))
        #expect(document.nodes[2].range == SourceRange(2, 4))
        #expect(document.nodes[2].data == .text("��"))
        #expect(HTMLRenderer().render(document) == "<h1>��</h1>\n")
    }

    @Test func basicReferenceDefinitionsAreCollectedAndDoNotRender() {
        let document = MarkdownParser().parse("[label]: <https://example.com> 'Title'\n\nBody\n")
        #expect(document.nodes[1].data == .referenceDefinition(ReferenceDefinition(
            rawLabel: "label", rawDestination: "https://example.com", rawTitle: "Title")))
        #expect(HTMLRenderer().render(document) == "<p>Body</p>\n")
        #expect(HTMLRenderer().render(MarkdownParser().parse("prefix\n[label]: /url\n")) == "<p>prefix\n[label]: /url</p>\n")
        #expect(HTMLRenderer().render(MarkdownParser().parse("[label]: /url junk\n")) == "<p>[label]: /url junk</p>\n")
        #expect(HTMLRenderer().render(MarkdownParser().parse("[label]: foo\\ bar\n")) == "<p>[label]: foo\\ bar</p>\n")
        #expect(HTMLRenderer().render(MarkdownParser().parse("[\u{00A0}]: /url\n")) == "<p>[\u{00A0}]: /url</p>\n")
    }

    @Test func sourceHTMLIsEscapedAndBlockAnchorsAreExplicit() {
        let document = MarkdownParser().parse("<script>alert(1)</script>\n")
        #expect(HTMLRenderer().render(document) == "<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>\n")
        #expect(HTMLRenderer(includeSourceRanges: true).render(document).hasPrefix("<p data-source-start=\"0\" data-source-end=\"26\">"))
        #expect(HTMLRenderer.escape("<\u{0301}&\"😀") == "&lt;\u{0301}&amp;&quot;😀")
        let code = MarkdownParser().parse("```x\"onmouseover=bad\ncode\n```\n")
        #expect(HTMLRenderer().render(code) == "<pre><code class=\"language-x&quot;onmouseover=bad\">code\n</code></pre>\n")
    }

    @Test func arbitraryBytesAndLongDelimiterRunsRemainUsable() {
        let parser = MarkdownParser()
        var state: UInt64 = 19
        for _ in 0..<128 {
            var bytes: [UInt8] = []
            for _ in 0..<256 {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                bytes.append(UInt8(truncatingIfNeeded: state >> 32))
            }
            let document = parser.parse(bytes: bytes)
            #expect(document.source == bytes)
            #expect(document.root.range == SourceRange(0, bytes.count))
            _ = HTMLRenderer().render(document)
        }
        for delimiter in ["#", "=", "`", "[", "_"] {
            let text = String(repeating: delimiter, count: 32_768)
            #expect(parser.parse(text).root.range.count == text.utf8.count)
        }
    }

    @Test func parserCanBeSharedAcrossConcurrentSnapshots() async {
        let parser = MarkdownParser()
        await withTaskGroup(of: String.self) { group in
            for index in 0..<16 {
                group.addTask { HTMLRenderer().render(parser.parse("# \(index)\n")) }
            }
            var results = Set<String>()
            for await result in group { results.insert(result) }
            #expect(results == Set((0..<16).map { "<h1>\($0)</h1>\n" }))
        }
    }
}
