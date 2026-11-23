import GMSetzer
import Testing

struct MarkdownHTMLTests {
    @Test func defaultsPreserveHTMLTrustBoundaries() throws {
        let source = "# Hello\n\n<script>alert(1)</script>\n\n<!-- hidden -->\n\n[bad](javascript:alert(1))\n"
        let html = try MarkdownHTML.render(source)
        #expect(html == HTMLRenderer().render(MarkdownParser().parse(source)))
        #expect(html.contains("&lt;script&gt;"))
        #expect(!html.contains("<!-- hidden -->"))
        #expect(!html.contains("href=\"javascript:"))
    }

    @Test func gfmSelectionKeepsTaskListsAndTables() throws {
        let parser = MarkdownParser(profile: .gfm)
        let source = "- [x] Done\n\n| A | B |\n| - | - |\n| 1 | 2 |\n"
        let html = try MarkdownHTML.render(source, parser: parser)
        #expect(html.contains("type=\"checkbox\""))
        #expect(html.contains("<table>"))
        #expect(html == HTMLRenderer().render(parser.parse(source)))
    }

    @Test func selectedExtensionsShareParseAndPresentation() throws {
        let implementations = [FrontMatter.implementation, Footnotes.implementation,
                               Alert.implementation, Callout.implementation]
        let parser = MarkdownParser(profile: Profile(name: "writing",
            extensions: Profile.gfm.extensions + implementations.map { ExtensionConfiguration($0.identifier) }),
            extensions: implementations)
        let source = "---\ntitle: hidden\n---\n\n> [!NOTE]\n> A note[^n].\n\n> [!tip]+ A *title*\n> Body\n\n[^n]: Footnote\n"
        let renderer = HTMLRenderer(hooks: [FrontMatter.kind: { _, _ in .replace("") }])
        let html = try MarkdownHTML.render(source, parser: parser, renderer: renderer)
        #expect(html.contains("markdown-alert-note"))
        #expect(html.contains("<details"))
        #expect(html.contains("A <em>title</em>"))
        #expect(html.contains("data-footnote-ref"))
        #expect(html.contains("data-footnotes"))
        #expect(!html.contains("title: hidden"))
        #expect(html == FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(renderer)).render(parser.parse(source)))
    }

    @Test func anUnselectedImplementationDoesNotEnableSyntax() throws {
        let source = "Text[^n].\n\n[^n]: Definition\n"
        let parser = MarkdownParser(extensions: [Footnotes.implementation])
        #expect(try MarkdownHTML.render(source, parser: parser) == MarkdownHTML.render(source))
    }

    @Test func invalidConfigurationThrows() throws {
        let parser = MarkdownParser(profile: Profile(name: "missing",
            extensions: [ExtensionConfiguration("missing")]))
        #expect(throws: ConfigurationError.self) {
            try MarkdownHTML.render("# Hello", parser: parser)
        }
    }

    @Test func frontMatterRetainsTheExistingSafeFallback() throws {
        let parser = MarkdownParser(profile: Profile(name: "metadata",
            extensions: [ExtensionConfiguration(FrontMatter.identifier)]),
            extensions: [FrontMatter.implementation])
        let html = try MarkdownHTML.render("---\ntitle: <b>metadata</b>\n---\n", parser: parser)
        #expect(html.contains("title: &lt;b&gt;metadata&lt;/b&gt;"))
    }

    @Test func originalBytesAndCallerPoliciesArePreserved() throws {
        let bytes: [UInt8] = [0xEF, 0xBB, 0xBF, 0x23, 0x20, 0xFF, 0x0A]
        #expect(try MarkdownHTML.render(bytes: bytes) == "<h1>�</h1>\n")
        let renderer = HTMLRenderer(allowRawHTML: true)
        #expect(try MarkdownHTML.render("<b>allowed</b>", renderer: renderer) == "<p><b>allowed</b></p>\n")
    }
}
