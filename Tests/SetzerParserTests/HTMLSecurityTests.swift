import GMSetzer
import Testing

struct HTMLSecurityTests {
    @Test func safeURLAllowlistAndEscapedDocumentContent() {
        let parser = MarkdownParser()
        for scheme in ["javascript", "vbscript", "data", "file", "shell", "custom-app"] {
            let html = HTMLRenderer().render(parser.parse("[x](\(scheme):payload) ![x](\(scheme):payload)"))
            #expect(html == "<p><a href=\"\">x</a> <img src=\"\" alt=\"x\" /></p>\n")
        }
        for url in ["https://example.org", "HTTP://example.org", "mailto:a@example.org", "../a:b", "/a:b", "//example.org:80/a", "#a", "?a=b"] {
            #expect(HTMLRenderer().render(parser.parse("[x](\(url))")).contains("href=\"\(url)\""))
        }
        let html = HTMLRenderer().render(parser.parse("<script>alert(1)</script>\n\n<img src=x onerror=evil>\n\n```\" onload=evil\n<&\n```"))
        #expect(!html.contains("<script>"))
        #expect(!html.contains("<img src=x"))
        #expect(html.contains("&lt;script&gt;"))
        #expect(html.contains("&lt;&amp;"))
    }

    @Test func anchorsAreUniqueEscapedAndAvailableToTrustedHooks() {
        let document = MarkdownParser().parse("- a\n\n  b\n\n# heading\n")
        let renderer = HTMLRenderer(includeSourceRanges: true, sourceAnchorPrefix: "preview-\"")
        let html = renderer.render(document)
        #expect(html.contains("id=\"preview-&quot;1\""))
        #expect(html.contains("data-source-start=\"0\""))
        let hook = HTMLRenderer(sourceAnchorPrefix: "p-", contextualHooks: [.heading: { context in
            #expect(context.parent == 0)
            #expect(context.sourceAnchorID == "p-\(context.index)")
            return .wrapChildren(open: "<header>", close: "</header>")
        }])
        #expect(hook.render(document).contains("<header>heading</header>"))
        #expect(!HTMLRenderer.conformance.render(document).contains("data-source"))
    }

    @Test func allowedURLSchemesAreExplicitAndValidated() {
        let document = MarkdownParser().parse("[t](tel:+491) [f](FTP://h/x) [j](javascript:x) [r](a/b:c)")
        let standard = HTMLRenderer().render(document)
        #expect(standard.contains("<a href=\"\">t</a>") && standard.contains("<a href=\"\">f</a>"))
        let extended = HTMLRenderer(allowedURLSchemes: [.https, .tel, .ftp]).render(document)
        #expect(extended.contains("href=\"tel:+491\""))
        #expect(extended.contains("href=\"FTP://h/x\""))
        #expect(extended.contains("<a href=\"\">j</a>"))
        #expect(extended.contains("href=\"a/b:c\""))
        #expect(HTMLRenderer(allowedURLSchemes: []).render(MarkdownParser().parse("[x](https://a)")).contains("href=\"\""))
        #expect(HTMLURLScheme(rawValue: "Web+App")?.rawValue == "web+app")
        for invalid in ["", "1abc", "a b", "ä", "java:script"] { #expect(HTMLURLScheme(rawValue: invalid) == nil) }
    }
}
