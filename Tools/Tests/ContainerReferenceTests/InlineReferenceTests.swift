import Foundation
import GMSetzer
import Testing
import cmark_gfm

/// Original, balanced inline fragments avoid the pinned C implementation's
/// 0.29 nested-strong differences. The 0.31.2 fixtures remain authoritative for
/// those inputs, rather than treating a historical oracle as the specification.
struct InlineReferenceTests {
    @Test func generatedInlineDocumentsMatchPinnedCmark() throws {
        let fragments = ["plain", "*em*", "**strong**", "_em_", "`a *b*`", "`` a`b ``", "a  \nb", "a\\\nb",
                         "[a *b*](/url \"title\")", "![a `b`](image)", "<x a='b'>", "&amp; &#x1F600;", "\\*literal\\*",
                         "<https://example.org/a?b=c&d=e>", "<mail@example.org>", "[ref]", "😀 ä 日本語"]
        let parser = MarkdownParser()
        let renderer = HTMLRenderer.conformance
        var count = 0
        for first in fragments {
            for second in fragments {
                for prefix in ["", "> ", "- "] {
                    let source = prefix + first + " " + second + "\n\n[ref]: /target 'Title'\n"
                    let actual = renderer.render(parser.parse(source))
                    let expected = ContainerReferenceTests.reference(source, renderOptions: CMARK_OPT_UNSAFE)
                    #expect(actual == expected, "Inline reference input: \(source)")
                    count += 1
                }
            }
        }
        print("Inline oracle: \(count) exact C comparisons")
    }
}
