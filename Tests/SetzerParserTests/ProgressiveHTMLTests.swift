import GMSetzer
import Synchronization
import Testing

struct ProgressiveHTMLTests {
    private final class Counter: Sendable {
        let value = Mutex(0)
        func increment() { value.withLock { $0 += 1 } }
        var count: Int { value.withLock { $0 } }
    }
    private enum Stop: Error { case requested }

    static func assembled(_ plan: HTMLRenderPlan) throws -> String {
        var output = ""
        try plan.forEachGroup { _, html in output += html; return true }
        return output
    }

    @Test func completeBlocksRetainForwardLinksListsTablesAndSourceAnchors() throws {
        let source = "# Heading\n\n[first][later]\n\n- a\n- b\n  - c\n\n| a | b |\n| - | - |\n| x | y |\n\n```swift\nlet x = 1\n```\n\n[later]: https://example.com\n"
        let document = MarkdownParser(profile: .gfm).parse(source)
        let renderer = HTMLRenderer(includeSourceRanges: true, sourceAnchorPrefix: "block-")
        let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
        #expect(plan.mode == .structural)
        #expect(plan.groups.count == document.children(of: 0).filter { document.nodes[$0].kind != .referenceDefinition }.count)
        #expect(try Self.assembled(plan) == renderer.render(document))
        for group in plan.groups {
            #expect(group.kind == .body && group.nodeIndices.count == 1)
            #expect(group.sourceRange == document.nodes[group.nodeIndices[0]].range)
        }
        let reverse = try plan.groups.reversed().map { ($0.ordinal, try plan.renderGroup(at: $0.ordinal)) }
        #expect(reverse.sorted { $0.0 < $1.0 }.map(\.1).joined() == renderer.render(document))
    }

    @Test func firstGroupDoesNotEvaluateLaterHooksAndConsumptionCanStop() throws {
        let counter = Counter()
        let renderer = HTMLRenderer(hooks: [.paragraph: { _, _ in
            counter.increment()
            return .wrapChildren(open: "<p>", close: "</p>\n")
        }], hookBehavior: .independent)
        let document = MarkdownParser().parse("one\n\ntwo\n\nthree\n")
        let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
        #expect(counter.count == 0)
        #expect(try plan.renderGroup(at: 1) == "<p>two</p>\n")
        #expect(counter.count == 1)
        let count = try plan.forEachGroup { group, html in
            #expect(group.ordinal == 0 && html == "<p>one</p>\n")
            return false
        }
        #expect(count == 1 && counter.count == 2)
    }

    @Test func unknownHooksAndDocumentWrappersUseExplicitWholeDocumentFallbacks() throws {
        let document = MarkdownParser().parse("one\n\ntwo\n")
        let counter = Counter()
        let ordered = HTMLRenderer(hooks: [.paragraph: { _, _ in counter.increment(); return nil }])
        let orderedPlan = try ordered.prepare(document, maximumSourceBytesPerGroup: 1)
        #expect(orderedPlan.mode == .wholeDocument(.documentOrderHooks))
        #expect(counter.count == 0 && orderedPlan.groups.count == 1)
        #expect(try Self.assembled(orderedPlan) == "<p>one</p>\n<p>two</p>\n")
        #expect(counter.count == 2)
        let wrapped = HTMLRenderer(hooks: [.document: { _, _ in .wrapChildren(open: "<article>", close: "</article>") }],
                                   hookBehavior: .independent)
        let wrappedPlan = try wrapped.prepare(document)
        #expect(wrappedPlan.mode == .wholeDocument(.documentHook))
        #expect(try Self.assembled(wrappedPlan) == wrapped.render(document))
    }

    @Test func rawHTMLCrossBlockWrappersAndUnsafeURLsKeepTheExistingPolicy() throws {
        let document = MarkdownParser(profile: .gfm).parse("<div>\n\none\n\n</div>\n\n[bad](javascript:alert(1))\n\n<!-- hidden -->\n")
        let renderer = HTMLRenderer()
        let safe = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
        #expect(safe.mode == .structural)
        let html = try Self.assembled(safe)
        #expect(html == renderer.render(document))
        #expect(!html.contains("<div>") && !html.contains("hidden") && html.contains("href=\"\""))
        let raw = try HTMLRenderer.conformance.prepare(document, maximumSourceBytesPerGroup: 1)
        #expect(raw.mode == .wholeDocument(.rawHTML) && raw.groups.count == 1)
        #expect(try Self.assembled(raw) == HTMLRenderer.conformance.render(document))
    }

    @Test func emptyDocumentsAndInvalidRequestsHaveDefinedResults() throws {
        let document = MarkdownParser().parse("")
        let plan = try HTMLRenderer().prepare(document)
        #expect(plan.groups.isEmpty)
        #expect(try Self.assembled(plan).isEmpty)
        #expect(throws: HTMLRenderPlanError.invalidGroupSize) {
            try HTMLRenderer().prepare(document, maximumSourceBytesPerGroup: 0)
        }
        #expect(throws: HTMLRenderPlanError.invalidGroupSize) {
            try FootnotesHTMLRenderer().prepare(document, maximumSourceBytesPerGroup: -1)
        }
        #expect(throws: HTMLRenderPlanError.invalidGroupIndex(-1)) { try plan.renderGroup(at: -1) }
        #expect(throws: HTMLRenderPlanError.invalidGroupIndex(0)) { try plan.renderGroup(at: 0) }
    }

    @Test func sourceBudgetKeepsOversizedBlocksIntactAndDoesNotSplitUTF8() throws {
        let source = "# ä😀\r\n\r\n```\r\n" + String(repeating: "日本語<&\r\n", count: 100) + "```\r\n\r\nend\r\n"
        let bytes = [UInt8(0xef), 0xbb, 0xbf] + Array(source.utf8) + [0xff, 0]
        let document = MarkdownParser().parse(bytes: bytes)
        let renderer = HTMLRenderer(includeSourceRanges: true)
        let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 20)
        #expect(plan.groups.contains { $0.sourceRange.count > plan.maximumSourceBytesPerGroup })
        #expect(plan.groups.allSatisfy { group in group.nodeIndices.allSatisfy { document.nodes[$0].kind != .text } })
        #expect(try Self.assembled(plan) == renderer.render(document))
        let grouped = try renderer.prepare(document, maximumSourceBytesPerGroup: 1_000_000)
        #expect(grouped.groups.count == 1)
    }

    @Test func cancellationStopsBeforeAndDuringOutputWithoutChangingTheReusablePlan() throws {
        let document = MarkdownParser().parse("# one\n\n*two* **three**\n\nfour\n")
        let renderer = HTMLRenderer()
        let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
        var checkpoints = 0, delivered = 0
        #expect(throws: Stop.requested) {
            try plan.forEachGroup(checkpoint: {
                checkpoints += 1
                if checkpoints == 2 { throw Stop.requested }
            }) { _, _ in delivered += 1; return true }
        }
        #expect(checkpoints == 2 && delivered == 0)
        #expect(try Self.assembled(plan) == renderer.render(document))
    }

    @Test func nonRenderingDefinitionsDoNotDelayTheFirstUsefulGroup() throws {
        let source = "[link]: https://example.com\n\n[^a]: A note\n\nUse [link] and [^a].\n"
        let document = FootnoteTests.parser().parse(source)
        let renderer = FootnotesHTMLRenderer()
        let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
        #expect(plan.groups.count == 2)
        #expect(try plan.renderGroup(at: 0).hasPrefix("<p>Use <a"))
        #expect(try Self.assembled(plan) == renderer.render(document))
        let custom = HTMLRenderer(hooks: [.referenceDefinition: { _, _ in .replace("<hr>\n") }], hookBehavior: .independent)
        let customPlan = try custom.prepare(document, maximumSourceBytesPerGroup: 1)
        #expect(try customPlan.renderGroup(at: 0) == "<hr>\n")
        #expect(try Self.assembled(customPlan) == custom.render(document))
    }

    @Test func footnotesUseGlobalNumberingAndALazySingleAppendix() throws {
        let document = FootnoteTests.parser().parse("B[^b]\n\nA[^a] B[^b]\n\n[^a]: Alpha[^b]\n[^b]: Beta[^a]\n")
        let renderer = FootnotesHTMLRenderer(renderer: HTMLRenderer(includeSourceRanges: true), idPrefix: "ä<&", backlinkLabel: "Back <&")
        let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
        #expect(plan.mode == .structural)
        #expect(plan.groups.filter { $0.kind == .appendix }.count == 1)
        #expect(plan.groups.last?.kind == .appendix)
        let appendix = try plan.renderGroup(at: plan.groups.count - 1)
        #expect(appendix.hasPrefix("<section class=\"footnotes\""))
        #expect(try Self.assembled(plan) == renderer.render(document))
        let reverse = try plan.groups.reversed().map { ($0.ordinal, try plan.renderGroup(at: $0.ordinal)) }
        #expect(reverse.sorted { $0.0 < $1.0 }.map(\.1).joined() == renderer.render(document))
        #expect(throws: Stop.requested) {
            var checkpoints = 0
            return try plan.renderGroup(at: plan.groups.count - 1, checkpoint: {
                checkpoints += 1
                if checkpoints == 4 { throw Stop.requested }
            })
        }
        let rawRenderer = FootnotesHTMLRenderer(renderer: .conformance)
        let fallback = try rawRenderer.prepare(document)
        #expect(fallback.mode == .wholeDocument(.rawHTML) && fallback.groups.count == 1)
        #expect(try Self.assembled(fallback) == rawRenderer.render(document))
    }

    @Test func allM5CompositionsReuseContextAcrossGroupsAndPreserveCustomHookFallbacks() throws {
        let implementations = [Alert.implementation, Callout.implementation, FrontMatter.implementation,
                               Footnotes.implementation, Math.implementation]
        let profile = Profile(name: "all-m5", extensions: Profile.gfm.extensions + implementations.map { ExtensionConfiguration($0.identifier) })
        let document = MarkdownParser(profile: profile, extensions: implementations, collectSyntaxDetails: true).parse(
            "---\ntitle: x\n---\n\n> [!note]- Title $x$[^a]\n> Body\n\nnext[^a]\n\n[^a]: note\n\n    > [!WARNING]\n    > inside\n")
        let math: ContextualHTMLRendererHook = { context in
            Math(context.tree.document, at: context.index).map { .replace("<span>\(HTMLRenderer.escape($0.tex))</span>") }
        }
        for behavior in [HTMLHookBehavior.independent, .documentOrder] {
            let base = HTMLRenderer(includeSourceRanges: true, sourceAnchorPrefix: "s-",
                hooks: [FrontMatter.kind: { _, _ in .replace("") }], contextualHooks: [Math.inlineKind: math], hookBehavior: behavior)
            let renderer = FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(base))
            let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
            #expect(plan.mode == (behavior == .independent ? .structural : .wholeDocument(.documentOrderHooks)))
            #expect(try Self.assembled(plan) == renderer.render(document))
            #expect(renderer.render(document).contains("Title <span>x</span><sup>"))
        }
    }

    @Test func independentPlanCanBeConsumedConcurrently() async throws {
        let document = MarkdownParser().parse(String(repeating: "# heading\n\nparagraph\n\n", count: 12))
        let renderer = HTMLRenderer(includeSourceRanges: true)
        let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 1)
        let output = try await withThrowingTaskGroup(of: (Int, String).self) { tasks in
            for group in plan.groups { tasks.addTask { (group.ordinal, try plan.renderGroup(at: group.ordinal)) } }
            var results: [(Int, String)] = []
            for try await result in tasks { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1).joined()
        }
        #expect(output == renderer.render(document))
    }
}
