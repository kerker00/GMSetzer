import BenchmarkCorpus
import GMSetzer
import Testing

struct BenchmarkCorpusTests {
    @Test(arguments: [100_000, 1_000_000, 5_000_000])
    func annotationWorkloadActuallyCollectsOptionalSyntax(_ bytes: Int) {
        let text = Corpus.referenceDocument(bytes: bytes)
        #expect(text.utf8.count >= bytes)
        #expect(text.utf8.count < bytes + Corpus.referenceBlock.utf8.count)
        let plain = MarkdownParser().parse(text)
        let annotated = MarkdownParser(collectSyntaxDetails: true).parse(text)
        let definitions = annotated.nodes.compactMap { node -> ReferenceDefinition? in
            if case .referenceDefinition(let value) = node.data { return value }
            return nil
        }
        #expect(!definitions.isEmpty)
        #expect(annotated.tokens?.isEmpty == false)
        #expect(plain.tokens == nil)
        #expect(annotated.nodes == plain.nodes)
        #expect(HTMLRenderer().render(plain) == HTMLRenderer().render(annotated))
        #expect(annotated.diagnostics.isEmpty)
        #expect(annotated.source == Array(text.utf8))
        let registryParser = try? Corpus.registryParser().validated()
        #expect(registryParser != nil)
        let mixed = Corpus.document(bytes: bytes)
        #expect(registryParser?.parse(mixed).nodes == MarkdownParser().parse(mixed).nodes)
        #expect(mixed.utf8.count >= bytes)
        #expect(mixed.utf8.count < bytes + Corpus.block.utf8.count)
    }
}
