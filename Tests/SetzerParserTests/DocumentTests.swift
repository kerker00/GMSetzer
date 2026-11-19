import GMSetzer
import Testing

struct DocumentTests {
    @Test func everyDocumentHasARootCoveringTheSource() {
        let document = MarkdownParser().parse("# Title\n")
        #expect(document.root.kind == .document)
        #expect(document.root.range == SourceRange(0, 8))
        #expect(document.children(of: 0).isEmpty)
    }
}
