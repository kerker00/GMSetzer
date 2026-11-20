import GMSetzer
import Testing

/// Deliberately small architecture probes, not complete footnote/math features.
struct ContainerExtensionTests {
    static let footnote = NodeKind("footnote.definition")
    static let implementation = MarkdownExtension("footnote", nodeKinds: [footnote], blockRules: [
        BlockRule("definition", trigger: 91) { context in
            let line = context.line
            guard context.source[line.contentRange.lowerBound..<line.contentRange.upperBound].starts(with: Array("[^x]: ".utf8)),
                  let first = context.droppingASCII(6, from: line) else { return nil }
            var children = [first]
            var consumed = 1
            while let next = context.line(at: context.lineIndex + consumed),
                  let content = context.droppingIndentation(4, from: next) {
                children.append(content)
                consumed += 1
            }
            let marker = SourceRange(line.contentRange.lowerBound, first.contentRange.lowerBound)
            return BlockMatch(consumedLines: consumed, data: .custom(kind: footnote, role: .block, attributes: [:]),
                children: children, tokens: [BlockToken("footnote.marker", range: marker)],
                diagnostics: [ParseDiagnostic(.extensionFinding(owner: "footnote", code: "probe", message: "Probe definition"), range: marker)])
        },
    ])

    @Test(arguments: ["[^x]: body\r\n    second\r\n", "> [^x]: body\r\n>     second\r\n", "- [^x]: body\r\n      second\r\n"])
    func parsedChildrenRetainSnapshotOffsetsAndEnclosingBoundaries(_ text: String) throws {
        let parser = try MarkdownParser(profile: Profile(name: "probe", extensions: [ExtensionConfiguration("footnote")]),
            extensions: [Self.implementation], collectSyntaxDetails: true).validated()
        let document = parser.parse(text)
        let owner = try #require(document.nodes.firstIndex { $0.kind == Self.footnote })
        #expect(document.children(of: owner).map { document.nodes[$0].kind } == [.paragraph])
        #expect(HTMLRenderer().render(document).contains("body\nsecond"))
        #expect(document.tokens?.first?.owner == owner)
        #expect(document.tokens?.first?.role == "footnote.marker")
        #expect(document.diagnostics.count == 1)
        #expect(document.source == Array(text.utf8))
        #expect(document.customLeafFallbacks.isEmpty)
        _ = try Document(source: document.source, nodes: document.nodes, diagnostics: document.diagnostics, tokens: document.tokens)
        let boundary = parser.parse("- [^x]: body\n- other\n")
        #expect(boundary.nodes.filter { $0.kind == .listItem }.count == 2)
    }

    @Test func recursiveExtensionsAreBoundedAndRetainOverflowSource() {
        let kind = NodeKind("recursive.container")
        let implementation = MarkdownExtension("recursive", nodeKinds: [kind], blockRules: [BlockRule("container") { context in
            BlockMatch(consumedLines: 1, data: .custom(kind: kind, role: .block, attributes: [:]), children: [context.line])
        }])
        let parser = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("recursive")]),
            extensions: [implementation], limits: ParserLimits(maximumContainerDepth: 8))
        let document = parser.parse("retained\n")
        #expect(document.nodes.count == 10)
        #expect(document.diagnostics.map(\.code) == [.nestingLimitExceeded(8)])
        #expect(HTMLRenderer().render(document) == "retained\n")
    }

    @Test func invalidChildOrderTokensAndDiagnosticsFallBackAtomically() {
        let kind = NodeKind("test.container")
        for mode in 0..<3 {
            let implementation = MarkdownExtension("test", nodeKinds: [kind], blockRules: [BlockRule("block") { context in
                guard let next = context.line(at: context.lineIndex + 1) else { return nil }
                return BlockMatch(consumedLines: 2, data: .custom(kind: kind, role: .block, attributes: [:]),
                    children: mode == 0 ? [next, context.line] : nil,
                    tokens: mode == 1 ? [BlockToken("foreign.marker", range: context.line.range)] : [],
                    diagnostics: mode == 2 ? [ParseDiagnostic(.extensionFinding(owner: "foreign", code: "bad", message: "bad"), range: context.line.range)] : [])
            }])
            let document = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("test")]), extensions: [implementation]).parse("one\ntwo\n")
            #expect(document.nodes[1].kind == .paragraph)
            #expect(document.tokens == nil)
            #expect(document.diagnostics.map(\.code) == [.invalidExtensionResult("test.block")])
        }
    }
}
