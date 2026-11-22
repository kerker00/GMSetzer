import BenchmarkCorpus
import GMSetzer
import Testing

struct HardeningWorkloadTests {
    @Test(arguments: HardeningWorkload.allCases)
    func generatedInputsPreserveBytesAnnotationsAndGroupedOutput(_ workload: HardeningWorkload) throws {
        for size in [512, 4_096, 16_384] {
            let bytes = workload.source(minimumBytes: size)
            #expect(bytes == workload.source(minimumBytes: size))
            #expect(bytes.count >= size && bytes.count < size + 2_048)
            let plain = try workload.parser(collectSyntaxDetails: false).parse(bytes: bytes)
            let annotated = try workload.parser(collectSyntaxDetails: true).parse(bytes: bytes)
            #expect(plain.source == bytes && annotated.source == bytes)
            #expect(plain.tokens == nil && annotated.tokens != nil)
            #expect(plain.nodes == annotated.nodes && plain.diagnostics == annotated.diagnostics)
            #expect(plain.customLeafFallbacks == annotated.customLeafFallbacks)
            #expect(plain.renderingPolicy == annotated.renderingPolicy)
            #expect(!annotated.diagnostics.contains {
                if case .invalidExtensionResult = $0.code { return true }
                return false
            })
            _ = try Document(source: annotated.source, nodes: annotated.nodes,
                diagnostics: annotated.diagnostics, customLeafFallbacks: annotated.customLeafFallbacks,
                tokens: annotated.tokens, renderingPolicy: annotated.renderingPolicy)
            #expect(SourceIndex(annotated).utf16Count == String(decoding: bytes, as: UTF8.self).utf16.count)
            let renderer = workload.renderer
            let expected = renderer.render(plain)
            #expect(renderer.render(annotated) == expected)
            let plan = try renderer.prepare(annotated, maximumSourceBytesPerGroup: 1)
            let reversed = try plan.groups.reversed().map { ($0.ordinal, try plan.renderGroup(at: $0.ordinal)) }
            #expect(reversed.sorted { $0.0 < $1.0 }.map(\.1).joined() == expected)
        }
    }

    @Test func composedWorkloadExercisesAllSelectedExtensions() throws {
        let workload = HardeningWorkload.composedM5
        let document = try workload.parser(collectSyntaxDetails: true).parse(bytes: workload.source(minimumBytes: 4_096))
        let kinds = Set(document.nodes.map(\.kind))
        #expect(kinds.isSuperset(of: [FrontMatter.kind, Footnotes.definitionKind, Footnotes.referenceKind,
            Math.inlineKind, Math.blockKind, Alert.kind, Callout.kind, .table]))
        #expect(Footnotes.Index(document).notes.count > 1)
        #expect(document.tokens?.isEmpty == false)
    }

    @Test func repeatedFootnotesKeepOneDefinitionAndManyReferences() throws {
        let workload = HardeningWorkload.repeatedFootnotes
        let document = try workload.parser(collectSyntaxDetails: true).parse(bytes: workload.source(minimumBytes: 4_096))
        let notes = Footnotes.Index(document).notes
        #expect(notes.count == 1)
        let references = document.nodes.filter { $0.kind == Footnotes.referenceKind }.count
        #expect(references > 100 && notes.first?.references.count == references)
        #expect(document.nodes.filter { $0.kind == Footnotes.definitionKind }.count == 1)
    }

    @Test func hostileShapesActuallyReachTheirIntendedPaths() throws {
        for workload in [HardeningWorkload.openBrackets, .unmatchedBackticks] {
            let bytes = workload.source(minimumBytes: 4_096)
            let document = try workload.parser(collectSyntaxDetails: false).parse(bytes: bytes)
            #expect(!document.nodes.contains { [.link, .image, .code, .codeBlock].contains($0.kind) })
            #expect(HTMLRenderer().render(document) == "<p>" + String(decoding: bytes, as: UTF8.self) + "</p>\n")
        }
        let emphasis = try HardeningWorkload.emphasis.parser(collectSyntaxDetails: false)
            .parse(bytes: HardeningWorkload.emphasis.source(minimumBytes: 4_096))
        #expect(emphasis.nodes.filter { $0.kind == .strong }.count > 100)
        let nested = try HardeningWorkload.nesting.parser(collectSyntaxDetails: false)
            .parse(bytes: HardeningWorkload.nesting.source(minimumBytes: 4_096))
        #expect(nested.diagnostics.contains { $0.code == .nestingLimitExceeded(128) })
        let invalid = try HardeningWorkload.invalidUTF8.parser(collectSyntaxDetails: false)
            .parse(bytes: HardeningWorkload.invalidUTF8.source(minimumBytes: 4_096))
        let html = HTMLRenderer().render(invalid)
        #expect(html.contains("\u{FFFD}") && !html.contains("\0"))
    }
}
