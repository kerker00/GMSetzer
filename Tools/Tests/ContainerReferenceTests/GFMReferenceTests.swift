import Foundation
import GMSetzer
import Testing
import cmark_gfm
import cmark_gfm_extensions

/// GMSetzer's GFM profile against pinned cmark-gfm with all five extensions,
/// on generated documents from GFM fragments. cmark-gfm spells the task list
/// checkbox differently from the normalised spec fixture; only that spelling
/// is mapped. Core lazy-continuation lines after a backslash hard break are
/// excluded: cmark-gfm keeps their indentation, CommonMark 0.31.2 does not.
struct GFMReferenceTests {
    static func reference(_ text: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()
        let parser = cmark_parser_new(CMARK_OPT_DEFAULT)!
        defer { cmark_parser_free(parser) }
        for name in ["table", "tasklist", "strikethrough", "autolink", "tagfilter"] {
            cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension(name))
        }
        text.withCString { cmark_parser_feed(parser, $0, text.utf8.count) }
        let document = cmark_parser_finish(parser)!
        defer { cmark_node_free(document) }
        let html = cmark_render_html(document, CMARK_OPT_UNSAFE, cmark_parser_get_syntax_extensions(parser))!
        defer { free(html) }
        return String(cString: html)
            .replacingOccurrences(of: "<input type=\"checkbox\" checked=\"\" disabled=\"\" /> ",
                                  with: "<input checked=\"\" disabled=\"\" type=\"checkbox\"> ")
            .replacingOccurrences(of: "<input type=\"checkbox\" disabled=\"\" /> ", with: "<input disabled=\"\" type=\"checkbox\"> ")
    }

    static let fragments = [
        "| a | b |", "|---|---|", "| - | :-: |", "a | b", "--- | ---", ":-|-:", "| x |", "|", "x \\| y", "| `a\\|b` |",
        "> | q |", "> |-|", "- | a |", "    | code |", "", "text", "| **b** | ~~s~~ |", "|a|b|c|", "| :--- |",
        "\t| a |", "| a |\t", " | a | ", "| \\\\| |", "| [l](u) |", "| &amp; | &#124; |", "   | b |",
        "- [ ] a", "- [x] b", "* [X] c", "1. [ ] d", "- [ ]", "  - [x] e", "> - [ ] f", "-  [ ] g", "- [ ]    code", "2) [x] h",
        "~a~", "~~b~~", "~~~c~~~", "a~~b~~c", "~~x~", "~ y ~", "~~**x**~~", "**~~x~~**", "> ~~q~~", "~~ ~~", "_~~a~~_",
        "www.example.com", "http://x.y/z(a)", "(www.a.b)", "foo@bar.com", "mailto:a@b.co", "xmpp:a@b.c/d", "www.a_b.c",
        "https://a.b/c?d=e&f;", "*www.x.y*", "[www.z.com](u)", "<www.q.com>", "x.y@z", "a@b.c.", "ftp://f.g", "HTTP://UP.ER",
        "www.x.com/a_b_c", "https://x.y/(a)b)", "a.b@c.d-e", "foo@bar.baz_", "`www.code.com`", "![www.img.com](u)",
        "hello@x.y@z.w", "(foo@bar.com)", "&#64;a@b.cd", "a\\@b.cd", "www.a.b&amp;", "http://a.b<c",
        "<script>x</script>", "<title>", "<div>", "<xmp>", "<style>", "# h", "***", "```", "[r]: /u", "1. a",
    ]

    static func excluded(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return zip(lines, lines.dropFirst()).contains { $0.hasSuffix("\\") && ($1.hasPrefix(" ") || $1.hasPrefix("\t")) }
    }

    @Test func generatedGFMDocumentsMatchCmarkGFM() throws {
        var documents: [String] = []
        for first in Self.fragments { for second in Self.fragments { documents.append(first + "\n" + second + "\n") } }
        var state: UInt64 = 4711
        for _ in 0..<6_000 {
            var text = ""
            for _ in 0..<(2 + Int((state >> 40) % 6)) {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                text += Self.fragments[Int((state >> 32) % UInt64(Self.fragments.count))] + "\n"
            }
            documents.append(text)
        }
        documents += documents.prefix(2_000).map { $0.replacingOccurrences(of: "\n", with: "\r\n") }
        documents.removeAll(where: Self.excluded)
        let parser = MarkdownParser(profile: .gfm)
        var failures: [[String: String]] = []
        for text in documents {
            let actual = HTMLRenderer.conformance.render(parser.parse(text))
            let expected = Self.reference(text)
            if actual != expected { failures.append(["markdown": text, "actual": actual, "expected": expected]) }
        }
        for failure in failures.prefix(20) {
            let data = try JSONSerialization.data(withJSONObject: failure, options: [.sortedKeys])
            print("GFM_REFERENCE_FAILURE \(String(decoding: data, as: UTF8.self))")
        }
        let failureCount = failures.count
        #expect(failureCount == 0, "\(failureCount) of \(documents.count) generated GFM documents differ from cmark-gfm")
    }
}
