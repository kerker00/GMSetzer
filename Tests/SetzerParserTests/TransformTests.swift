import GMSetzer
import Testing

struct TransformTests {
    static let kind = NodeKind("alert.block")

    static let alerts = MarkdownExtension("alert", nodeKinds: [kind], transforms: [BlockTransform("recognise") { document in
        // Probe: recognise one quote marker, keeping the topology and offsets.
        var nodes = document.nodes
        for (index, node) in nodes.enumerated() where node.kind == .blockQuote {
            guard let paragraph = node.firstChild, let first = nodes[paragraph].firstChild,
                  case .text(let text) = nodes[first].data, text.hasPrefix("[!NOTE] ") else { continue }
            nodes[index] = Node(data: .custom(kind: kind, role: .block, attributes: [:]), range: node.range,
                sourceSegments: node.sourceSegments, firstChild: node.firstChild, nextSibling: node.nextSibling)
            let old = nodes[first]
            nodes[first] = Node(data: .text(String(text.dropFirst(8))), range: old.range,
                sourceSegments: [SourceRange(old.range.lowerBound + 8, old.range.upperBound)], nextSibling: old.nextSibling)
        }
        return try Document(source: document.source, nodes: nodes, diagnostics: document.diagnostics,
            customLeafFallbacks: document.customLeafFallbacks, tokens: document.tokens)
    }])

    @Test func alertsTransformBeforeInlinesWithoutLosingQuoteListContext() throws {
        let parser = try MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("alert")]), extensions: [Self.alerts]).validated()
        let document = parser.parse("- > [!NOTE] body\n")
        #expect(document.nodes.contains { $0.kind == Self.kind })
        #expect(document.diagnostics.isEmpty)
        let renderer = HTMLRenderer(contextualHooks: [Self.kind: { context in
            #expect(context.ancestors.map { context.tree.document.nodes[$0].kind } == [.listItem, .list, .document])
            return .wrapChildren(open: "<aside>\n", close: "</aside>\n")
        }])
        #expect(renderer.render(document) == "<ul>\n<li>\n<aside>\n<p>body</p>\n</aside>\n</li>\n</ul>\n")
        let disabled = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("alert")], disabledRules: ["alert.recognise"]), extensions: [Self.alerts])
        #expect(!disabled.parse("> [!NOTE] body\n").nodes.contains { $0.kind == Self.kind })
    }

    @Test func rebuiltTreesMayRemapForeignOwnersButCannotForgeSpellingOrDuplicateTokens() throws {
        let kind = NodeKind("test.marker")
        for mode in 0..<4 {
            let implementation = MarkdownExtension("test", nodeKinds: [kind], transforms: [BlockTransform("rebuild") { document in
                var builder = DocumentBuilder(source: document.source, collectSyntaxDetails: true)
                builder.renderingPolicy = document.renderingPolicy
                try builder.append(.custom(kind: kind, role: .block, attributes: [:]), range: SourceRange(0, 0), fallbackLiteral: "")
                var mapped = [Int](repeating: 0, count: document.nodes.count)
                var pending = document.children(of: 0).reversed().map { ($0, 0) }
                while let (old, parent) = pending.popLast() {
                    let node = document.nodes[old]
                    let new = try builder.append(node.data, range: node.range, sourceSegments: node.sourceSegments,
                        fallbackLiteral: document.customLeafFallbacks[old], to: parent)
                    mapped[old] = new
                    for child in document.children(of: old).reversed() { pending.append((child, new)) }
                }
                for token in document.tokens ?? [] {
                    builder.record(SyntaxToken(token.role, range: token.range, owner: mapped[token.owner]))
                }
                if let first = document.tokens?.first {
                    if mode == 1 { builder.record(SyntaxToken(first.role, range: first.range, owner: mapped[first.owner])) }
                    if mode == 2 { builder.record(SyntaxToken("core.invented", range: first.range, owner: mapped[first.owner])) }
                    if mode == 3 { builder.record(SyntaxToken(first.role, range: SourceRange(0, 1), owner: mapped[first.owner])) }
                }
                return try builder.build()
            }])
            let parser = try MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("test")]),
                extensions: [implementation], collectSyntaxDetails: true).validated()
            let document = parser.parse("> text\n")
            #expect(HTMLRenderer().render(document) == "<blockquote>\n<p>text</p>\n</blockquote>\n")
            if mode == 0 {
                #expect(document.diagnostics.isEmpty)
                #expect(document.tokens?.first?.owner == 2)
                #expect(document.nodes[2].kind == .blockQuote)
            } else {
                #expect(document.diagnostics.map(\.code) == [.invalidExtensionResult("test.rebuild")])
                #expect(!document.nodes.contains { $0.kind == kind })
            }
        }
    }

    @Test func rejectedOrThrowingTransformsKeepThePreviousSnapshot() {
        enum ProbeError: Error { case rejected }
        for mode in 0..<3 {
            let implementation = MarkdownExtension("test", nodeKinds: [], transforms: [BlockTransform("bad") { document in
                if mode == 0 { throw ProbeError.rejected }
                if mode == 1 { return MarkdownParser().parse("changed") }
                var builder = DocumentBuilder(source: document.source)
                try builder.append(.custom(kind: NodeKind("foreign.block"), role: .block, attributes: [:]), range: document.root.range)
                return try builder.build()
            }])
            let document = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("test")]), extensions: [implementation]).parse("original\n")
            #expect(HTMLRenderer().render(document) == "<p>original</p>\n")
            #expect(document.source == Array("original\n".utf8))
            #expect(document.diagnostics.map(\.code) == [.invalidExtensionResult("test.bad")])
        }
    }
}
