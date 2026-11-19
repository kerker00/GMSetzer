import GMSetzer
import Testing

struct SyntaxTreeTests {
    @Test func documentedTreesAreExecutableContracts() {
        let document = MarkdownParser().parse("## A\n\none\ntwo\n")
        #expect(document.nodes.map(\.data) == [.document, .heading(level: 2), .text("A"),
                                              .paragraph, .text("one"), .softBreak, .text("two")])
        #expect(document.nodes.map(\.range) == [SourceRange(0, 14), SourceRange(0, 5), SourceRange(3, 4),
                                               SourceRange(6, 14), SourceRange(6, 9), SourceRange(9, 10), SourceRange(10, 13)])
        #expect(document.nodes[3].sourceSegments == [SourceRange(6, 9), SourceRange(10, 13)])
        let code = MarkdownParser().parse("```txt\nx\n```\n")
        #expect(code.nodes.count == 2)
        #expect(code.nodes[1].data == .codeBlock(info: "txt", literal: "x\n"))
        #expect(code.nodes[1].range == SourceRange(0, 13))
        #expect(code.nodes[1].sourceSegments == [SourceRange(7, 9)])
        let reference = MarkdownParser().parse("[a]: /x\n\nA\n")
        #expect(reference.nodes.map(\.data) == [.document, .referenceDefinition(ReferenceDefinition(rawLabel: "a", rawDestination: "/x")),
                                               .paragraph, .text("A")])
        #expect(reference.nodes.map(\.range) == [SourceRange(0, 11), SourceRange(0, 8), SourceRange(9, 11), SourceRange(9, 10)])
    }

    @Test func builderPreservesSourceSegmentsAndSiblingOrder() throws {
        var builder = DocumentBuilder(source: Array("> a\n> b\n".utf8))
        let custom = try builder.append(.custom(kind: NodeKind("example.quote"), role: .block, attributes: ["folded": .boolean(true)]),
                                        range: SourceRange(0, 8), sourceSegments: [SourceRange(2, 4), SourceRange(6, 8)])
        let first = try builder.append(.text("a"), range: SourceRange(2, 3), to: custom)
        let second = try builder.append(.text("b"), range: SourceRange(6, 7), to: custom)
        let document = try builder.build()
        #expect(document.children(of: custom) == [first, second])
        #expect(document.nodes[custom].sourceSegments == [SourceRange(2, 4), SourceRange(6, 8)])
        #expect(document.source == Array("> a\n> b\n".utf8))
    }

    @Test func rejectsInvalidTopologyWithoutTraversingForever() {
        #expect(throws: DocumentError.invalidRoot) { try Document(source: [], nodes: []) }
        #expect(throws: DocumentError.invalidIndex(node: 0, target: 8)) {
            try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0), firstChild: 8)])
        }
        #expect(throws: DocumentError.repeatedNode(0)) {
            try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0), firstChild: 0)])
        }
        #expect(throws: DocumentError.unreachableNode(1)) {
            try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0)),
                                           Node(data: .paragraph, range: SourceRange(0, 0))])
        }
    }

    @Test func rejectsRangesOutsideParentsAndOverlappingSiblings() {
        #expect(throws: DocumentError.invalidRange(node: 2)) {
            try Document(source: Array("abc".utf8), nodes: [
                Node(data: .document, range: SourceRange(0, 3), firstChild: 1),
                Node(data: .paragraph, range: SourceRange(0, 1), firstChild: 2),
                Node(data: .text("bc"), range: SourceRange(1, 3)),
            ])
        }
        #expect(throws: DocumentError.unorderedSiblings(node: 1)) {
            try Document(source: Array("abc".utf8), nodes: [
                Node(data: .document, range: SourceRange(0, 3), firstChild: 1),
                Node(data: .paragraph, range: SourceRange(0, 2), nextSibling: 2),
                Node(data: .paragraph, range: SourceRange(1, 3)),
            ])
        }
    }

    @Test func rejectsInvalidContentModelsAndPayloads() {
        #expect(throws: DocumentError.invalidChild(parent: 0, child: 1)) {
            try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0), firstChild: 1),
                                           Node(data: .text(""), range: SourceRange(0, 0))])
        }
        for data in [NodeData.heading(level: 0), .heading(level: 7),
                     .custom(kind: .paragraph, role: .block, attributes: [:])] {
            #expect(throws: DocumentError.invalidPayload(node: 1)) {
                try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0), firstChild: 1),
                                               Node(data: data, range: SourceRange(0, 0))])
            }
        }
        #expect(throws: DocumentError.invalidSegments(node: 1)) {
            try Document(source: Array("abc".utf8), nodes: [
                Node(data: .document, range: SourceRange(0, 3), firstChild: 1),
                Node(data: .paragraph, range: SourceRange(0, 3), sourceSegments: [SourceRange(2, 3), SourceRange(0, 1)]),
            ])
        }
    }

    @Test func builderRejectsUnknownParents() throws {
        var builder = DocumentBuilder(source: [])
        #expect(throws: DocumentError.invalidParent(-1)) {
            try builder.append(.paragraph, range: SourceRange(0, 0), to: -1)
        }
    }

    @Test func deeplyNestedCustomTreesValidateAndRenderIteratively() throws {
        var builder = DocumentBuilder(source: Array("x".utf8))
        var parent = 0
        for _ in 0..<2_000 {
            parent = try builder.append(.custom(kind: NodeKind("example.container"), role: .block, attributes: [:]),
                                        range: SourceRange(0, 1), to: parent)
        }
        try builder.append(.text("x"), range: SourceRange(0, 1), to: parent)
        #expect(HTMLRenderer().render(try builder.build()) == "x")
    }
}
