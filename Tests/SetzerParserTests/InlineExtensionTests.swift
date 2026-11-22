import GMSetzer
import Testing
import Synchronization

struct InlineExtensionTests {
    static let kind = NodeKind("test.mark")
    static let data = NodeData.custom(kind: kind, role: .inline, attributes: [:])
    static let marker = InlineRule("mark", trigger: 61) { context in
        guard context.runLength == 2 else { return nil }
        let token = BlockToken("test.marker", range: SourceRange(context.offset, context.offset + 2))
        if context.canClose, let opener = context.openers.last {
            return InlineMatch(consumed: 2, data: data, delimiter: .close(opener, width: 2), tokens: [token])
        }
        if context.canOpen { return InlineMatch(consumed: 2, data: data, delimiter: .open(width: 2), tokens: [token]) }
        return nil
    }

    static func parser(rules: [InlineRule] = [marker], order: [String] = [], disabled: Set<String> = [],
                       transforms: [BlockTransform] = [], collect: Bool = true, depth: Int = 16) -> MarkdownParser {
        MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("test")],
                                       disabledRules: disabled, ruleOrder: order),
            extensions: [MarkdownExtension("test", nodeKinds: [kind], inlineRules: rules, postInlineTransforms: transforms)],
            limits: ParserLimits(maximumInlineExtensionDepth: depth), collectSyntaxDetails: collect)
    }
    static let renderer = HTMLRenderer(hooks: [kind: { _, _ in .wrapChildren(open: "<mark>", close: "</mark>") }])

    @Test func customDelimitersShareTheCoreControllerAndRespectProtectedSyntax() throws {
        let parser = try Self.parser().validated()
        let source = "==a *b*== `==c==` \\==d== [==e==](a==b)\n"
        let document = parser.parse(source)
        #expect(Self.renderer.render(document) == "<p><mark>a <em>b</em></mark> <code>==c==</code> ==d== <a href=\"a==b\"><mark>e</mark></a></p>\n")
        #expect(document.diagnostics.isEmpty)
        #expect(document.nodes.filter { $0.kind == Self.kind }.count == 2)
        #expect(document.tokens!.filter { $0.role == "test.marker" }.count == 4)
        let plain = Self.parser(collect: false).parse(source)
        #expect(plain.tokens == nil)
        #expect(plain.nodes == document.nodes)
        let disabled = Self.parser(disabled: ["test.mark"]).parse("==a==")
        #expect(Self.renderer.render(disabled) == "<p>==a==</p>\n")
        #expect(Self.renderer.render(parser.parse("==[a==](u)")) == "<p>==<a href=\"u\">a==</a></p>\n")
    }

    @Test func invalidInlineMatchesAreRejectedBeforeAnyMutation() {
        for mode in 0..<7 {
            let rule = InlineRule("bad", trigger: 36) { context in
                let data: NodeData = mode == 1 ? .text("bad") : Self.data
                let consumed = mode == 0 ? Int.max : mode == 2 ? 0 : 1
                let tokens = mode == 3 ? [BlockToken("foreign.marker", range: SourceRange(context.offset, context.offset + 1))] : []
                let child = mode == 4 ? SourceRange(0, context.input.count + 1) : nil
                let delimiter: DelimiterRequest = mode == 5 ? .open(width: 2) : mode == 6 ? .open(width: 0) : .none
                return InlineMatch(consumed: consumed, data: data, children: child, delimiter: delimiter, tokens: tokens)
            }
            let document = Self.parser(rules: [rule]).parse("$x")
            #expect(Self.renderer.render(document) == "<p>$x</p>\n")
            #expect(document.diagnostics.map(\.code) == [.invalidExtensionResult("test.bad")])
            #expect(!document.nodes.contains { $0.kind == Self.kind })
            #expect(document.tokens == [])
        }
    }

    @Test func foreignRuleHandlesAreNotEligibleAndPrecedenceIsExplicit() throws {
        let foreign = InlineRule("foreign", trigger: 61, priority: -1) { context in
            if let opener = context.openers.last {
                return InlineMatch(consumed: 2, data: Self.data, delimiter: .close(opener, width: 2))
            }
            return nil
        }
        let first = try Self.parser(rules: [Self.marker, foreign], order: ["test.foreign", "test.mark"]).validated()
        #expect(Self.renderer.render(first.parse("==x==")) == "<p><mark>x</mark></p>\n")
        let duplicate = Self.parser(rules: [Self.marker, Self.marker])
        #expect(duplicate.configurationIssues.contains { $0.code == .duplicateIdentifier })
        #expect(Self.parser(order: ["core.code"]).configurationIssues.contains { $0.code == .unknownRule })
    }

    @Test func retainedHandlesFromPreviousParsesCannotCloseNewDelimiters() {
        let retained = Mutex<DelimiterHandle?>(nil)
        let rule = InlineRule("stale", trigger: 61) { context in
            guard context.runLength == 2 else { return nil }
            if let previous = retained.withLock({ $0 }) {
                return InlineMatch(consumed: 2, data: Self.data, delimiter: .close(previous, width: 2))
            }
            if let opener = context.openers.last {
                retained.withLock { $0 = opener }
                return nil
            }
            return InlineMatch(consumed: 2, data: Self.data, delimiter: .open(width: 2))
        }
        let parser = Self.parser(rules: [rule])
        _ = parser.parse("==a==")
        let next = parser.parse("==b==")
        #expect(Self.renderer.render(next) == "<p>==b==</p>\n")
        #expect(next.diagnostics.count == 2)
        #expect(!next.nodes.contains { $0.kind == Self.kind })
    }

    @Test func preInlineTokensSurviveTextReplacement() {
        let transform = BlockTransform("annotate") { document in
            let text = document.nodes.indices.first { document.nodes[$0].kind == .text }!
            return try Document(source: document.source, nodes: document.nodes,
                tokens: (document.tokens ?? []) + [SyntaxToken("test.before", range: document.nodes[text].range, owner: text)])
        }
        let parser = MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("test")]),
            extensions: [MarkdownExtension("test", nodeKinds: [], transforms: [transform])], collectSyntaxDetails: true)
        let document = parser.parse("*a*")
        let token = document.tokens!.first { $0.role == "test.before" }!
        #expect(token.range == SourceRange(0, 3))
        #expect(document.nodes[token.owner].kind == .paragraph)
    }

    @Test func callbackProjectionsRetainOriginalCRLFAndContainerOffsets() throws {
        let rule = InlineRule("probe", trigger: 36) { context in
            guard context.input[context.offset...].starts(with: Array("$a\nb$".utf8)) else { return nil }
            #expect(context.originalRanges(for: SourceRange(context.offset, context.offset + 5)) == [SourceRange(7, 11), SourceRange(13, 15)])
            return InlineMatch(consumed: 5, data: Self.data, children: SourceRange(context.offset + 1, context.offset + 4),
                tokens: [BlockToken("test.span", range: SourceRange(context.offset, context.offset + 5))])
        }
        let document = try Self.parser(rules: [rule]).validated().parse("> 😀 $a\r\n> b$\n")
        #expect(Self.renderer.render(document) == "<blockquote>\n<p>😀 <mark>a\nb</mark></p>\n</blockquote>\n")
        #expect(document.diagnostics.isEmpty)
    }

    @Test func completeChildMatchesAreBoundedAndPostInlineTransformsSeeResolvedNodes() {
        let recursive = InlineRule("recursive", trigger: 36) { context in
            InlineMatch(consumed: context.input.count - context.offset, data: Self.data, children: SourceRange(context.offset + 1, context.input.count))
        }
        let transform = BlockTransform("post") { document in
            #expect(document.nodes.contains { $0.kind == .emphasis })
            return document
        }
        let parser = Self.parser(transforms: [transform])
        #expect(Self.renderer.render(parser.parse("==*a*==")) == "<p><mark><em>a</em></mark></p>\n")
        for depth in [1, 16, 32] {
            let nested = Self.parser(rules: [recursive], depth: depth).parse(String(repeating: "$", count: 64))
            #expect(nested.diagnostics.contains { $0.code == .nestingLimitExceeded(depth) })
            #expect(Self.renderer.render(nested).contains("$"))
        }
    }
}

extension InlineExtensionTests {
    @Test func declinedLongCustomRunsKeepProgressWithoutRescanningTheSuffix() {
        let rule = InlineRule("decline", trigger: 61) { _ in nil }
        let source = "x " + String(repeating: "=", count: 16_384)
        let document = Self.parser(rules: [rule], collect: false).parse(source)
        #expect(document.diagnostics.isEmpty)
        #expect(HTMLRenderer().render(document) == "<p>\(source)</p>\n")
    }
}

extension InlineExtensionTests {
    @Test func nestedTokensKeepOrderAndEmptyCRLFPositionsAcrossLeaves() throws {
        let outer = InlineRule("outer", trigger: 36) { context in
            InlineMatch(consumed: context.input.count, data: Self.data,
                children: SourceRange(1, context.input.count - 1),
                tokens: [BlockToken("test.outer", range: SourceRange(0, 1))])
        }
        let point = InlineRule("point", trigger: 97) { context in
            let ranges = [SourceRange(1, 1), SourceRange(2, 2), SourceRange(0, 3)]
            return InlineMatch(consumed: context.input.count, data: Self.data,
                tokens: (0..<13).map { BlockToken("test.point.\($0)", range: ranges[$0 % 3]) })
        }
        for source in ["$a\r\nb$\r\n\r\n$a\r\nb$\r\n", "> $a\r\n> b$\r\n>\r\n> $a\r\n> b$\r\n"] {
            let document = try Self.parser(rules: [outer, point]).validated().parse(source)
            let plain = Self.parser(rules: [outer, point], collect: false).parse(source)
            let owners = document.nodes.indices.filter {
                document.nodes[$0].kind == Self.kind && document.nodes[$0].firstChild == nil
            }
            #expect(owners.count == 2 && document.diagnostics.isEmpty)
            var expected: [SyntaxToken] = []
            for owner in owners {
                let range = document.nodes[owner].range
                let beforeEnding = SourceRange(range.lowerBound + 1, range.lowerBound + 1)
                let afterEnding = SourceRange(range.upperBound - 1, range.upperBound - 1)
                let pieces = range.lowerBound + 3 == range.upperBound - 1 ? [range]
                    : [SourceRange(range.lowerBound, range.lowerBound + 3), SourceRange(range.upperBound - 1, range.upperBound)]
                for ordinal in 0..<13 {
                    let projected = ordinal % 3 == 0 ? [beforeEnding] : ordinal % 3 == 1 ? [afterEnding] : pieces
                    for piece in projected {
                        expected.append(SyntaxToken("test.point.\(ordinal)", range: piece, owner: owner))
                    }
                }
            }
            #expect(document.tokens?.filter { $0.role.hasPrefix("test.point.") } == expected)
            #expect(document.tokens?.filter { $0.role == "test.outer" }.count == 2)
            #expect(document.nodes == plain.nodes && document.diagnostics == plain.diagnostics)
            #expect(Self.renderer.render(document) == Self.renderer.render(plain))
            _ = try Document(source: document.source, nodes: document.nodes, diagnostics: document.diagnostics,
                customLeafFallbacks: document.customLeafFallbacks, tokens: document.tokens,
                renderingPolicy: document.renderingPolicy)
        }
    }

    @Test func emptyProjectedPositionsAfterCRLFStayAfterTheWholeEnding() {
        let outer = InlineRule("outer", trigger: 36) { context in
            InlineMatch(consumed: context.input.count, data: Self.data, children: SourceRange(1, 3))
        }
        let point = InlineRule("point", trigger: 97) { context in
            #expect(context.originalRanges(for: SourceRange(2, 2)) == [SourceRange(4, 4)])
            return InlineMatch(consumed: 2, data: Self.data,
                               tokens: [BlockToken("test.point", range: SourceRange(2, 2))])
        }
        let document = Self.parser(rules: [outer, point]).parse("$a\r\nb$")
        #expect(document.diagnostics.isEmpty)
        #expect(document.tokens!.first { $0.role == "test.point" }!.range == SourceRange(4, 4))
    }

    @Test func firstReferenceUsesSourceOrderAfterAValidStorageReordering() throws {
        let reorder = BlockTransform("order") { document in
            let order = [0] + Array(document.nodes.indices.dropFirst().reversed())
            var mapping = [Int](repeating: 0, count: order.count)
            for (new, old) in order.enumerated() { mapping[old] = new }
            let nodes = order.map { old in
                let node = document.nodes[old]
                return Node(data: node.data, range: node.range, sourceSegments: node.sourceSegments,
                            firstChild: node.firstChild.map { mapping[$0] }, nextSibling: node.nextSibling.map { mapping[$0] })
            }
            return try Document(source: document.source, nodes: nodes)
        }
        let parser = try MarkdownParser(profile: Profile(name: "test", extensions: [ExtensionConfiguration("test")]),
            extensions: [MarkdownExtension("test", nodeKinds: [], transforms: [reorder])]).validated()
        let document = parser.parse("[a]: /first\n[a]: /second\n\n[a]\n")
        #expect(document.diagnostics.isEmpty)
        #expect(HTMLRenderer().render(document) == "<p><a href=\"/first\">a</a></p>\n")
    }
}
