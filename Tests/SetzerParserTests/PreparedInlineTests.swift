import GMSetzer
import Synchronization
import Testing

struct PreparedInlineTests {
    static let kind = NodeKind("prepared.reference")
    static let data = NodeData.custom(kind: kind, role: .inline, attributes: [:])

    static func parser(_ rule: InlineRule) throws -> MarkdownParser {
        try MarkdownParser(profile: Profile(name: "prepared", extensions: [ExtensionConfiguration("prepared")]),
            extensions: [MarkdownExtension("prepared", nodeKinds: [kind], inlineRules: [rule])], collectSyntaxDetails: true).validated()
    }

    @Test func factoryPreparesEachSnapshotOnceAndDoesNotLeakStateBetweenParses() throws {
        let preparations = Mutex(0)
        let rule = InlineRule("reference", trigger: 91, allowsBracketSyntax: true, prepare: { document in
            preparations.withLock { $0 += 1 }
            let enabled = document.nodes.contains { $0.kind == .heading }
            return { context in
                guard enabled, context.offset + 3 <= context.input.count,
                      context.input[context.offset..<(context.offset + 3)].elementsEqual("[x]".utf8) else { return nil }
                return InlineMatch(consumed: 3, data: Self.data,
                    tokens: [BlockToken("prepared.marker", range: SourceRange(context.offset, context.offset + 3))])
            }
        })
        let parser = try Self.parser(rule)
        let enabled = parser.parse("# Heading\n\n[x] *[x]*\n\n[x]\n")
        #expect(enabled.nodes.filter { $0.kind == Self.kind }.count == 3)
        #expect(enabled.tokens?.filter { $0.role == "prepared.marker" }.count == 3)
        #expect(enabled.diagnostics.isEmpty)
        let disabled = parser.parse("[x]\n\n[x]\n")
        #expect(!disabled.nodes.contains { $0.kind == Self.kind })
        #expect(preparations.withLock { $0 } == 2)
    }

    @Test func bracketsRemainProtectedUnlessExplicitlyEnabledAndConsumedContextsStayProtected() throws {
        for optedIn in [false, true] {
            let rule = InlineRule("reference", trigger: 91, allowsBracketSyntax: optedIn) { context in
                guard context.offset + 3 <= context.input.count,
                      context.input[context.offset..<(context.offset + 3)].elementsEqual("[x]".utf8) else { return nil }
                return InlineMatch(consumed: 3, data: Self.data)
            }
            let parser = try Self.parser(rule)
            let document = parser.parse("[x] `[x]` \\[x] [outer [x]](url) ![alt [x]](image) [dest](path[x]) <i title='[x]'>\n")
            #expect(document.nodes.filter { $0.kind == Self.kind }.count == (optedIn ? 1 : 0))
            #expect(document.diagnostics.isEmpty)
        }
    }

    @Test func bracketRulesCannotOpenDelimiterHandlesOrPartiallyMutateTheTree() throws {
        let rule = InlineRule("reference", trigger: 91, allowsBracketSyntax: true) { context in
            InlineMatch(consumed: 1, data: Self.data, delimiter: .open(width: 1),
                tokens: [BlockToken("prepared.marker", range: SourceRange(context.offset, context.offset + 1))])
        }
        let document = try Self.parser(rule).parse("[x]")
        #expect(HTMLRenderer().render(document) == "<p>[x]</p>\n")
        #expect(!document.nodes.contains { $0.kind == Self.kind })
        #expect(document.tokens?.isEmpty == true)
        #expect(document.diagnostics.map(\.code) == [.invalidExtensionResult("prepared.reference")])
    }
}
