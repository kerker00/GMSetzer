import GMSetzer
import Testing

extension SpecTests {
    @Test func progressiveOutputPreservesBothCompleteCorpora() throws {
        for corpus in ["commonmark-0.31.2", "gfm-0.29"] {
            let examples = try Self.examples(corpus)
            for example in examples {
                let profile = corpus.hasPrefix("gfm") ? Self.gfmProfile(for: example) : .commonMark
                let document = MarkdownParser(profile: profile).parse(example.markdown)
                for renderer in [HTMLRenderer(), HTMLRenderer.conformance] {
                    let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
                    var joined = ""
                    try plan.forEachGroup { _, html in joined += html; return true }
                    #expect(joined == renderer.render(document), "\(corpus) example \(example.example)")
                }
            }
        }
    }
}
