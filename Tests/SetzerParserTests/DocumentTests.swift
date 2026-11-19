import GMSetzer
import Testing

struct DocumentTests {
    @Test func everyDocumentHasARootCoveringTheSource() {
        let document = MarkdownParser().parse("# Title\n")
        #expect(document.root.kind == .document)
        #expect(document.root.range == SourceRange(0, 8))
        #expect(document.children(of: 0) == [1])
        #expect(document.nodes[1].data == .heading(level: 1))
        #expect(document.nodes[2].data == .text("Title"))
    }
}
