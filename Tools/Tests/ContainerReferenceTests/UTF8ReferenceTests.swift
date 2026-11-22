import BenchmarkCorpus
import Foundation
import GMSetzer
import Testing
import cmark_gfm

struct UTF8ReferenceTests {
    static func validatedReference(_ bytes: [UInt8]) throws -> String {
        let parser = cmark_parser_new(CMARK_OPT_SOURCEPOS | CMARK_OPT_VALIDATE_UTF8)!
        bytes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                cmark_parser_feed(parser, $0, buffer.count)
            }
        }
        let document = cmark_parser_finish(parser)!
        cmark_parser_free(parser)
        defer { cmark_node_free(document) }
        let html = cmark_render_html(document, CMARK_OPT_UNSAFE, nil)!
        defer { free(html) }
        return try #require(String(validatingUTF8: html))
    }

    @Test func compatibleControlsHaveIdenticalRepairOutput() throws {
        for workload in [UTF8Workload.compatibleMalformed, .validMultibyte] {
            for size in [512, 4_096, 16_384] {
                let bytes = workload.source(minimumBytes: size)
                #expect(bytes == workload.source(minimumBytes: size))
                #expect(bytes.count >= size && bytes.count < size + 64)
                let document = MarkdownParser().parse(bytes: bytes)
                let annotated = MarkdownParser(collectSyntaxDetails: true).parse(bytes: bytes)
                #expect(document.source == bytes && annotated.source == bytes)
                #expect(document.nodes == annotated.nodes && document.diagnostics == annotated.diagnostics)
                let actual = HTMLRenderer.conformance.render(document)
                #expect(actual == (try Self.validatedReference(bytes)))
                #expect(HTMLRenderer.conformance.render(annotated) == actual)
            }
        }
    }

    @Test func legacyCorpusRetainsItsDifferentMalformedSequencePolicy() throws {
        let bytes: [UInt8] = [120, 32, 0xc0, 0xaf, 10]
        #expect(HTMLRenderer.conformance.render(MarkdownParser().parse(bytes: bytes)) == "<p>x ��</p>\n")
        #expect(try Self.validatedReference(bytes) == "<p>x �</p>\n")
        #expect(UTF8Workload.legacyMalformed.source(minimumBytes: 4_096)
            == HardeningWorkload.invalidUTF8.source(minimumBytes: 4_096))
    }
}
