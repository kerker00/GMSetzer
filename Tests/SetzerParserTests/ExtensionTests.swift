import GMSetzer
import Testing

struct ExtensionTests {
    static let kind = NodeKind("example.notice")
    static let implementation = MarkdownExtension("example", nodeKinds: [Self.kind], options: ["title": ExtensionOption(.string)], blockRules: [
        BlockRule("notice", trigger: 58, interruptsParagraph: true) { context in
            let content = context.line.contentRange
            guard context.source[content.lowerBound..<content.upperBound].starts(with: [58, 58, 58]) else { return nil }
            return BlockMatch(consumedLines: 1, data: .custom(kind: kind, role: .block, attributes: context.options))
        },
    ])

    @Test func profileOptionsReachRulesAndRendererHooksAreSeparate() {
        let profile = Profile(name: "example", extensions: [ExtensionConfiguration("example", options: ["title": .string("A & B")])])
        let document = MarkdownParser(profile: profile, extensions: [Self.implementation]).parse("before\n::: notice\nafter\n")
        #expect(document.diagnostics.isEmpty)
        #expect(document.children(of: 0).map { document.nodes[$0].kind } == [.paragraph, Self.kind, .paragraph])
        let renderer = HTMLRenderer(hooks: [Self.kind: { node, _ in
            guard case .custom(_, _, let attributes) = node.data,
                  case .string(let title) = attributes["title"] else { return nil }
            return .replace("<aside>\(HTMLRenderer.escape(title))</aside>\n")
        }])
        #expect(renderer.render(document) == "<p>before</p>\n<aside>A &amp; B</aside>\n<p>after</p>\n")
        #expect(HTMLRenderer().render(document) == "<p>before</p>\n::: notice\n<p>after</p>\n")
    }

    @Test func rulesOnlyRunWhenSelectedAndStayOutOfCodeBlocks() {
        let disabled = MarkdownParser(extensions: [Self.implementation]).parse("::: notice\n")
        #expect(disabled.nodes[1].kind == .paragraph)
        let enabled = MarkdownParser(profile: Profile(name: "example", extensions: [ExtensionConfiguration("example")]),
                                     extensions: [Self.implementation])
        #expect(enabled.parse("```\n::: notice\n```\n").nodes[1].kind == .codeBlock)
        #expect(enabled.parse("    ::: notice\n").nodes[1].kind == .codeBlock)
    }

    @Test func prioritiesThenProfileOrderDetermineRuleSelection() {
        func implementation(_ id: String, priority: Int) -> MarkdownExtension {
            MarkdownExtension(id, nodeKinds: [NodeKind(id)], blockRules: [BlockRule(id, priority: priority) { _ in
                BlockMatch(consumedLines: 1, data: .custom(kind: NodeKind(id), role: .block, attributes: [:]))
            }])
        }
        let first = implementation("example.first", priority: 0)
        let second = implementation("example.second", priority: 1)
        let profile = Profile(name: "test", extensions: [ExtensionConfiguration(first.identifier), ExtensionConfiguration(second.identifier)])
        #expect(MarkdownParser(profile: profile, extensions: [first, second]).parse("x").nodes[1].kind == NodeKind(second.identifier))
        let tied = implementation("example.second", priority: 0)
        #expect(MarkdownParser(profile: profile, extensions: [tied, first]).parse("x").nodes[1].kind == NodeKind(first.identifier))
    }

    @Test(arguments: [0, -1, Int.max])
    func invalidConsumptionFallsBackWithoutLosingSource(_ count: Int) {
        let implementation = MarkdownExtension("broken", nodeKinds: [NodeKind("broken.notice")], blockRules: [BlockRule("broken") { _ in
            BlockMatch(consumedLines: count, data: .custom(kind: Self.kind, role: .block, attributes: [:]))
        }])
        let parser = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("broken")]), extensions: [implementation])
        let document = parser.parse("text\n")
        #expect(document.diagnostics.map(\.code) == [.invalidExtensionResult("broken")])
        #expect(HTMLRenderer().render(document) == "<p>text</p>\n")
    }

    @Test func invalidPayloadsAndSegmentsAreRejectedBeforeDocumentConstruction() {
        for match in [
            BlockMatch(consumedLines: 1, data: .heading(level: 99)),
            BlockMatch(consumedLines: 1, data: .custom(kind: .paragraph, role: .block, attributes: [:])),
            BlockMatch(consumedLines: 1, data: .custom(kind: Self.kind, role: .inline, attributes: [:])),
            BlockMatch(consumedLines: 1, data: .custom(kind: Self.kind, role: .block, attributes: [:]), sourceSegments: [SourceRange(0, 100)]),
        ] {
            let implementation = MarkdownExtension("broken", nodeKinds: [NodeKind("broken.notice")], blockRules: [BlockRule("broken") { _ in match }])
            let document = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("broken")]),
                                          extensions: [implementation]).parse("text")
            #expect(document.diagnostics.map(\.code) == [.invalidExtensionResult("broken")])
            #expect(HTMLRenderer().render(document) == "<p>text</p>\n")
        }
    }

    @Test func unavailableAndDuplicateRegistrationsAreVisible() {
        let unavailable = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("missing")]))
        #expect(unavailable.configurationIssues.map(\.code) == [.unavailableExtension])
        #expect(unavailable.parse("").diagnostics.isEmpty)
        #expect(throws: ConfigurationError.self) { try unavailable.validated() }
        let duplicate = MarkdownParser(extensions: [Self.implementation, Self.implementation])
        #expect(duplicate.configurationIssues.map(\.code) == [.duplicateIdentifier])
        #expect(duplicate.parse("").diagnostics.isEmpty)
    }

    @Test func hooksCanWrapChildrenWithoutIntroducingParserDependencies() throws {
        var builder = DocumentBuilder(source: Array("x".utf8))
        let parent = try builder.append(.custom(kind: Self.kind, role: .block, attributes: [:]), range: SourceRange(0, 1))
        try builder.append(.text("<x>"), range: SourceRange(0, 1), to: parent)
        let renderer = HTMLRenderer(hooks: [Self.kind: { _, _ in .wrapChildren(open: "<aside>", close: "</aside>") }])
        #expect(renderer.render(try builder.build()) == "<aside>&lt;x&gt;</aside>")
    }

    @Test func multilineRulesSeeProjectedLinesInsideContainers() {
        let implementation = MarkdownExtension("example", nodeKinds: [Self.kind], blockRules: [BlockRule("twoLines", trigger: 58) { context in
            guard let next = context.line(at: context.lineIndex + 1) else { return nil }
            let bytes = context.source[next.contentRange.lowerBound..<next.contentRange.upperBound]
            return BlockMatch(consumedLines: 2,
                              data: .custom(kind: Self.kind, role: .block, attributes: ["body": .string(String(decoding: bytes, as: UTF8.self))]),
                              sourceSegments: [context.line.contentRange, next.contentRange])
        }])
        let parser = MarkdownParser(profile: Profile(name: "example", extensions: [ExtensionConfiguration("example")]), extensions: [implementation])
        let document = parser.parse("> :::\n> text\n")
        #expect(document.diagnostics.isEmpty)
        #expect(document.nodes.map(\.kind) == [.document, .blockQuote, Self.kind])
        #expect(document.nodes[2].range == SourceRange(2, 13))
        #expect(document.nodes[2].sourceSegments == [SourceRange(2, 5), SourceRange(8, 12)])
        #expect(document.nodes[2].data == .custom(kind: Self.kind, role: .block, attributes: ["body": .string("text")]))
        let list = parser.parse("- :::\n- next\n")
        #expect(!list.nodes.contains { $0.kind == Self.kind })
        #expect(HTMLRenderer().render(list) == "<ul>\n<li>:::</li>\n<li>next</li>\n</ul>\n")
    }

    @Test func multilineRuleCannotConsumePastAContainerBoundary() {
        let implementation = MarkdownExtension("example", nodeKinds: [Self.kind], blockRules: [BlockRule("broken", trigger: 58) { _ in
            BlockMatch(consumedLines: 2, data: .custom(kind: Self.kind, role: .block, attributes: [:]))
        }])
        let parser = MarkdownParser(profile: Profile(name: "example", extensions: [ExtensionConfiguration("example")]), extensions: [implementation])
        let document = parser.parse("- :::\n- next\n")
        #expect(document.diagnostics.map(\.code) == [.invalidExtensionResult("example.broken")])
        #expect(HTMLRenderer().render(document) == "<ul>\n<li>:::</li>\n<li>next</li>\n</ul>\n")
    }
}
