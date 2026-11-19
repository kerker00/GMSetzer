import GMSetzer
import Testing

struct ContainerTests {
    @Test(arguments: [
        ("> first\nsecond\n>\n> third\n\noutside\n", "<blockquote>\n<p>first\nsecond</p>\n<p>third</p>\n</blockquote>\n<p>outside</p>\n"),
        ("> # head\noutside\n", "<blockquote>\n<h1>head</h1>\n</blockquote>\n<p>outside</p>\n"),
        ("> a\n2. b\n", "<blockquote>\n<p>a</p>\n</blockquote>\n<ol start=\"2\">\n<li>b</li>\n</ol>\n"),
        ("> a\n> 2. b\n", "<blockquote>\n<p>a\n2. b</p>\n</blockquote>\n"),
        ("> a\n-\n", "<blockquote>\n<p>a</p>\n</blockquote>\n<ul>\n<li></li>\n</ul>\n"),
        ("> ```\n> code\noutside\n", "<blockquote>\n<pre><code>code\n</code></pre>\n</blockquote>\n<p>outside</p>\n"),
        ("- a\n- b\n", "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n"),
        ("- a\n\n- b\n", "<ul>\n<li>\n<p>a</p>\n</li>\n<li>\n<p>b</p>\n</li>\n</ul>\n"),
        ("3) three\n4) four\n", "<ol start=\"3\">\n<li>three</li>\n<li>four</li>\n</ol>\n"),
        ("- a\n+ b\n", "<ul>\n<li>a</li>\n</ul>\n<ul>\n<li>b</li>\n</ul>\n"),
        ("1. a\n2) b\n", "<ol>\n<li>a</li>\n</ol>\n<ol start=\"2\">\n<li>b</li>\n</ol>\n"),
        ("- a\n  - b\n  - c\n- d\n", "<ul>\n<li>a\n<ul>\n<li>b</li>\n<li>c</li>\n</ul>\n</li>\n<li>d</li>\n</ul>\n"),
        ("- > a\n  >\n  > b\n- c\n", "<ul>\n<li>\n<blockquote>\n<p>a</p>\n<p>b</p>\n</blockquote>\n</li>\n<li>c</li>\n</ul>\n"),
        ("- a\n\n  b\n", "<ul>\n<li>\n<p>a</p>\n<p>b</p>\n</li>\n</ul>\n"),
        ("-\n-\n", "<ul>\n<li></li>\n<li></li>\n</ul>\n"),
        ("- a\n-\n- b\n", "<ul>\n<li>a</li>\n<li></li>\n<li>b</li>\n</ul>\n"),
        ("2. a\n3.\n4. b\n", "<ol start=\"2\">\n<li>a</li>\n<li></li>\n<li>b</li>\n</ol>\n"),
        ("para\n2. continuation\n", "<p>para\n2. continuation</p>\n"),
        ("para\n1. item\n", "<p>para</p>\n<ol>\n<li>item</li>\n</ol>\n"),
        ("1.     code\n", "<ol>\n<li>\n<pre><code>code\n</code></pre>\n</li>\n</ol>\n"),
        ("  -\talpha\n\tbeta\n", "<ul>\n<li>alpha\nbeta</li>\n</ul>\n"),
        ("-\t\tX\r\n", "<ul>\n<li>\n<pre><code>  X\n</code></pre>\n</li>\n</ul>\n"),
    ])
    func containerContinuationAndListRendering(_ fixture: (String, String)) {
        #expect(HTMLRenderer().render(MarkdownParser().parse(fixture.0)) == fixture.1)
    }

    @Test func nestedRangesExcludeAncestorPrefixesAndPreserveCRLFAndUnicode() {
        let bytes = Array("- > Ä\r\n  > B\r\n".utf8)
        let document = MarkdownParser().parse(bytes: bytes)
        #expect(document.source == bytes)
        #expect(document.nodes.map(\.kind) == [.document, .list, .listItem, .blockQuote, .paragraph, .text, .softBreak, .text])
        #expect(document.nodes[1].data == .list(ListAttributes(style: .bullet(marker: 45))))
        #expect(document.nodes[3].range == SourceRange(2, 15))
        #expect(document.nodes[4].range == SourceRange(4, 15))
        #expect(document.nodes[4].sourceSegments == [SourceRange(4, 6), SourceRange(12, 13)])
        #expect(document.nodes[6].range == SourceRange(6, 8))
        #expect(document.nodes[7].data == .text("B"))
    }

    @Test func partialTabsRetainOriginalProvenance() {
        let document = MarkdownParser().parse("-\t\tX\r\n")
        let code = document.nodes.first { $0.kind == .codeBlock }!
        #expect(code.data == .codeBlock(info: nil, literal: "  X\n"))
        #expect(code.sourceSegments == [SourceRange(2, 6)])
    }

    @Test func looseInnerListDoesNotLoosenItsParent() {
        let document = MarkdownParser().parse("- outer\n  - first\n\n  - second\n- end\n")
        let lists = document.nodes.compactMap { node -> ListAttributes? in
            if case .list(let attributes) = node.data { return attributes }; return nil
        }
        #expect(lists.map(\.isTight) == [true, false])
    }

    @Test func parserBoundsNestingAndRetainsOverflowSyntax() {
        let text = String(repeating: "> ", count: 10_000) + "x\n"
        let parser = MarkdownParser(limits: ParserLimits(maximumContainerDepth: 6))
        let document = parser.parse(text)
        #expect(document.diagnostics.map(\.code) == [.nestingLimitExceeded(6)])
        #expect(document.nodes.filter { $0.kind == .blockQuote }.count == 6)
        #expect(HTMLRenderer().render(document).contains("&gt; &gt;"))
        #expect(document.source == Array(text.utf8))
        let list = MarkdownParser(limits: ParserLimits(maximumContainerDepth: 1)).parse("- x\n")
        #expect(list.diagnostics.map(\.code) == [.nestingLimitExceeded(1)])
        #expect(HTMLRenderer().render(list) == "<p>- x</p>\n")
    }

    @Test func validatesListPayloadsAndItemParents() {
        for style in [ListStyle.bullet(marker: 0), .ordered(start: -1, delimiter: 46), .ordered(start: 1, delimiter: 0)] {
            #expect(throws: DocumentError.invalidPayload(node: 1)) {
                try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0), firstChild: 1),
                                               Node(data: .list(ListAttributes(style: style)), range: SourceRange(0, 0))])
            }
        }
        #expect(throws: DocumentError.invalidChild(parent: 0, child: 1)) {
            try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0), firstChild: 1),
                                           Node(data: .listItem, range: SourceRange(0, 0))])
        }
    }

    @Test func prefixHeavyInputsKeepValidTopologyAndOriginalBytes() {
        var state: UInt64 = 4711
        let alphabet = Array(">-+*012.) #=~`\t\r\naÄ😀".utf8)
        let parser = MarkdownParser(limits: ParserLimits(maximumContainerDepth: 12))
        for _ in 0..<256 {
            var bytes: [UInt8] = []
            for _ in 0..<256 {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                bytes.append(alphabet[Int((state >> 32) % UInt64(alphabet.count))])
            }
            let document = parser.parse(bytes: bytes)
            #expect(document.source == bytes)
            _ = HTMLRenderer().render(document)
        }
    }
}
