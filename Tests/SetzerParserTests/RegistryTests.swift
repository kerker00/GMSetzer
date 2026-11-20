import GMSetzer
import Testing

struct RegistryTests {
    @Test func disabledRulesAlsoStopInterruptingParagraphsAndReferences() throws {
        let disabled = Set(CoreBlockRule.allCases.map(\.rawValue))
        let parser = try MarkdownParser(profile: Profile(name: "literal", disabledRules: disabled)).validated()
        let text = "body\n# heading\n> quote\n- item\n```\n---\n<div>\n[x]: /u\n===\n"
        let document = parser.parse(text)
        #expect(document.children(of: 0).count == 1)
        #expect(document.nodes[1].kind == .paragraph)
        #expect(document.diagnostics.isEmpty)
        #expect(HTMLRenderer().render(document).contains("[x]: /u"))
        let lists = MarkdownParser(profile: Profile(name: "list", disabledRules: ["core.thematicBreak"]))
        #expect(lists.parse("- - -\n").nodes.contains { $0.kind == .list })
    }

    @Test func optionDefaultsValidationNamespaceAndDisabledCustomRules() throws {
        let kind = NodeKind("notice.block")
        let implementation = MarkdownExtension("notice", nodeKinds: [kind], options: [
            "level": ExtensionOption(.integer, defaultValue: .integer(2), integerRange: 1...3),
            "style": ExtensionOption(.string, allowedValues: [.string("tip"), .string("note")]),
        ], blockRules: [BlockRule("block", trigger: 58) { context in
            BlockMatch(consumedLines: 1, data: .custom(kind: kind, role: .block, attributes: context.options))
        }])
        let profile = Profile(name: "test", extensions: [ExtensionConfiguration("notice", options: [
            "level": .integer(99), "typo": .boolean(true), "style": .string("other"),
        ])], disabledRules: ["core.typo"])
        let parser = MarkdownParser(profile: profile, extensions: [implementation])
        #expect(parser.configurationIssues.map(\.code) == [.unknownRule, .invalidOption, .invalidOption, .unknownOption])
        #expect(throws: ConfigurationError.self) { try parser.validated() }
        let document = parser.parse(":")
        #expect(document.nodes[1].data == .custom(kind: kind, role: .block, attributes: ["level": .integer(2)]))
        #expect(document.diagnostics.isEmpty)
        let disabled = try MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("notice")],
            disabledRules: ["notice.block"]), extensions: [implementation]).validated()
        #expect(disabled.parse(":").nodes[1].kind == .paragraph)
        let foreign = MarkdownExtension("notice", nodeKinds: [NodeKind("other.block")], blockRules: [])
        let invalid = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("notice")]), extensions: [foreign])
        #expect(invalid.configurationIssues.map(\.code) == [.namespaceViolation])
    }

    @Test func foreignOutputsAndDuplicateRuleIdentitiesAreRejected() {
        let kind = NodeKind("owner.block")
        let rule = BlockRule("block") { _ in
            BlockMatch(consumedLines: 1, data: .custom(kind: NodeKind("foreign.block"), role: .block, attributes: [:]))
        }
        let implementation = MarkdownExtension("owner", nodeKinds: [kind], blockRules: [rule, rule, BlockRule("foreign.rule") { _ in nil }])
        let parser = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("owner")]), extensions: [implementation])
        #expect(parser.configurationIssues.map(\.code) == [.duplicateIdentifier, .namespaceViolation])
        #expect(parser.parse("x").diagnostics.map(\.code) == [.invalidExtensionResult("owner.block")])
    }

    @Test func explicitPrecedenceAppliesWithinTheOpeningPhase() throws {
        let kind = NodeKind("shadow.block")
        let implementation = MarkdownExtension("shadow", nodeKinds: [kind], blockRules: [BlockRule("block", trigger: 62) { _ in
            BlockMatch(consumedLines: 1, data: .custom(kind: kind, role: .block, attributes: [:]))
        }])
        let selected = [ExtensionConfiguration("shadow")]
        let defaultParser = MarkdownParser(profile: Profile(name: "test", extensions: selected), extensions: [implementation])
        #expect(defaultParser.parse("> body\n").nodes[1].kind == kind)
        let coreFirst = try MarkdownParser(profile: Profile(name: "test", extensions: selected, ruleOrder: ["core.blockQuote"]),
            extensions: [implementation]).validated()
        #expect(coreFirst.parse("> body\n").nodes[1].kind == .blockQuote)
    }

    @Test func snapshotIndexAndContextPreserveTightListSemantics() {
        let document = MarkdownParser().parse("- first\n- second\n")
        let tree = DocumentIndex(document)
        #expect(tree.parent(of: 0) == nil)
        #expect(tree.parent(of: -1) == nil)
        let paragraph = document.nodes.firstIndex { $0.kind == .paragraph }!
        #expect(tree.ancestors(of: paragraph).map { document.nodes[$0].kind } == [.listItem, .list, .document])
        let renderer = HTMLRenderer(contextualHooks: [.paragraph: { context in
            #expect(context.tightItem)
            #expect(context.parent != nil)
            #expect(context.ancestors.count == 3)
            return .wrapChildren(open: "", close: "")
        }])
        #expect(renderer.render(document) == HTMLRenderer().render(document))
        #expect(tree.document.source == document.source)
    }

    @Test func tokensAndFallbackHaveExplicitSnapshotLifetimes() throws {
        var builder = DocumentBuilder(source: [120], collectSyntaxDetails: true)
        let owner = try builder.append(.custom(kind: NodeKind("test.leaf"), role: .block, attributes: [:]), range: SourceRange(0, 1), fallbackLiteral: "projected")
        builder.record(SyntaxToken("test.marker", range: SourceRange(0, 0), owner: owner))
        let first = try builder.build()
        try builder.finish(owner, data: first.nodes[owner].data, range: SourceRange(0, 1))
        #expect(try builder.build().customLeafFallbacks[owner] == "projected")
        builder.clearFallback(for: owner)
        #expect(try builder.build().customLeafFallbacks.isEmpty)
        #expect(first.customLeafFallbacks[owner] == "projected")
        #expect(first.tokens?.count == 1)
        #expect(throws: DocumentError.invalidToken(0)) {
            try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0))],
                tokens: [SyntaxToken("test", range: SourceRange(0, 0), owner: 1)])
        }
    }
}
