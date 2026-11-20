import GMSetzer
@testable import SetzerParser
import Testing

struct InlineContractTests {
    static let kind = NodeKind("math.inline")
    static let descriptor = ExtensionDescriptor("math", nodeKinds: [kind])
    static let data = NodeData.custom(kind: kind, role: .inline, attributes: [:])

    @Test func mathCannotClaimEscapesCodeSpansOrLinkDestinations() {
        let match = InlineMatchDraft(consumed: 3, data: Self.data, children: SourceRange(1, 2), delimiter: .none,
            tokens: [BlockToken("math.marker", range: SourceRange(0, 1))])
        for protected in [false, true] {
            let context = InlineContextDraft(source: Array("$x$".utf8), content: SourceRange(0, 3), offset: 0,
                protected: protected, canOpen: true, canClose: false, runLength: 1, openers: [])
            #expect(InlineContractDraft.accepts(match, context: context, descriptor: Self.descriptor) == !protected)
        }
        for count in [0, -1, Int.max] {
            let bad = InlineMatchDraft(consumed: count, data: Self.data, children: nil, delimiter: .none, tokens: [])
            let context = InlineContextDraft(source: [36], content: SourceRange(0, 1), offset: 0,
                protected: false, canOpen: true, canClose: true, runLength: 1, openers: [])
            #expect(!InlineContractDraft.accepts(bad, context: context, descriptor: Self.descriptor))
        }
    }

    @Test func delimiterResolutionRequiresAnEligibleOwnedOpenerAndFlanking() {
        let opener = DelimiterHandleDraft(owner: "math", offset: 0, width: 2)
        let foreign = DelimiterHandleDraft(owner: "strike", offset: 0, width: 2)
        let stale = DelimiterHandleDraft(owner: "math", offset: 1, width: 2)
        for candidate in [opener, foreign, stale] {
            for canClose in [true, false] {
                let context = InlineContextDraft(source: Array("$$x$$".utf8), content: SourceRange(0, 5), offset: 3,
                    protected: false, canOpen: false, canClose: canClose, runLength: 2, openers: [opener])
                let match = InlineMatchDraft(consumed: 2, data: Self.data, children: nil, delimiter: .close(candidate, width: 2), tokens: [])
                #expect(InlineContractDraft.accepts(match, context: context, descriptor: Self.descriptor) == (candidate == opener && canClose))
                let tooWide = InlineMatchDraft(consumed: 2, data: Self.data, children: nil, delimiter: .close(candidate, width: 3), tokens: [])
                #expect(!InlineContractDraft.accepts(tooWide, context: context, descriptor: Self.descriptor))
            }
        }
    }
}
