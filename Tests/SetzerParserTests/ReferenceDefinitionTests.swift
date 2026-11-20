import GMSetzer
import Testing

struct ReferenceDefinitionTests {
    @Test func multilineDefinitionsAndOptionalTitleFallback() {
        let text = "[\nlabel\n]:\n<path with space>\n'first\nsecond'\n\nBody\n"
        let document = MarkdownParser().parse(text)
        #expect(document.nodes[1].data == .referenceDefinition(ReferenceDefinition(rawLabel: "\nlabel\n", rawDestination: "path with space", rawTitle: "first\nsecond")))
        #expect(HTMLRenderer().render(document) == "<p>Body</p>\n")
        #expect(HTMLRenderer().render(MarkdownParser().parse("[x]: /url\n'unclosed\ntext\n")) == "<p>'unclosed\ntext</p>\n")
        #expect(HTMLRenderer().render(MarkdownParser().parse("[x]: /url 'title' junk\n")) == "<p>[x]: /url 'title' junk</p>\n")
    }

    @Test(arguments: [
        ("[x]: /url\n---\n", "<p>---</p>\n"),
        ("[x]: /url\n-\n", "<p>-</p>\n"),
        ("[x]: /url\n===\n", "<p>===</p>\n"),
        ("[x]: /url\nbody\n===\n", "<h1>body</h1>\n"),
        ("- [x]: /url\n\n  body\n", "<ul>\n<li>body</li>\n</ul>\n"),
        ("- a\n\n  [x]: /url\n", "<ul>\n<li>a</li>\n</ul>\n"),
        ("[x]: /u\n[y]: /v\n\nbody\n", "<p>body</p>\n"),
        ("[x]: (balanced(url))\n", ""),
        ("[x]: (unbalanced\n", "<p>[x]: (unbalanced</p>\n"),
    ])
    func definitionsDoNotCreatePhantomHeadingsOrLooseLists(_ fixture: (String, String)) {
        #expect(HTMLRenderer().render(MarkdownParser().parse(fixture.0)) == fixture.1)
    }

    @Test func syntaxDetailsKeepExactContainerAndCRLFOffsets() {
        let text = "> [α]: <>\r\n> \"t\"\r\n"
        let plain = MarkdownParser().parse(text)
        let detailed = MarkdownParser(collectSyntaxDetails: true).parse(text)
        guard case .referenceDefinition(let reference) = detailed.nodes[2].data,
              case .referenceDefinition = plain.nodes[2].data,
              let syntax = detailed.referenceSyntax(for: 2) else { Issue.record("Expected reference details"); return }
        #expect(plain.tokens == nil)
        #expect(reference.rawLabel == "α")
        #expect(reference.rawDestination == "")
        #expect(reference.rawTitle == "t")
        #expect(syntax.label == [SourceRange(3, 5)])
        #expect(syntax.destination == [SourceRange(9, 9)])
        #expect(syntax.title == [SourceRange(15, 16)])
        #expect(syntax.markers == [SourceRange(2, 3), SourceRange(5, 6), SourceRange(6, 7),
                                   SourceRange(8, 9), SourceRange(9, 10), SourceRange(14, 15), SourceRange(16, 17)])
        #expect(detailed.nodes[2].range == SourceRange(2, 19))
        #expect(HTMLRenderer().render(plain) == HTMLRenderer().render(detailed))
    }

    @Test func metadataValidationRejectsRangesOutsideDefinition() {
        #expect(throws: DocumentError.invalidToken(0)) {
            try Document(source: [], nodes: [Node(data: .document, range: SourceRange(0, 0), firstChild: 1),
                Node(data: .referenceDefinition(ReferenceDefinition(rawLabel: "x", rawDestination: "")), range: SourceRange(0, 0))], tokens: [SyntaxToken("core.reference.label", range: SourceRange(0, 10), owner: 1)])
        }
    }

    @Test func labelLengthAndWhitespaceRulesAreEnforced() {
        let parser = MarkdownParser()
        #expect(parser.parse("[" + String(repeating: "α", count: 999) + "]: /u\n").nodes[1].kind == .referenceDefinition)
        #expect(parser.parse("[" + String(repeating: "α", count: 1_000) + "]: /u\n").nodes[1].kind == .paragraph)
        #expect(parser.parse("[ \n ]: /u\n").nodes[1].kind == .paragraph)
        #expect(parser.parse("[a[b]]: /u\n").nodes[1].kind == .paragraph)
    }

    @Test func replacementDecodingDoesNotShiftReferenceDetails() {
        let bytes: [UInt8] = [91, 0, 0xFF, 93, 58, 32, 60, 62, 13, 10]
        let document = MarkdownParser(collectSyntaxDetails: true).parse(bytes: bytes)
        guard case .referenceDefinition(let definition) = document.nodes[1].data else { Issue.record("Expected reference"); return }
        #expect(document.source == bytes)
        #expect(definition.rawLabel == "��")
        #expect(document.referenceSyntax(for: 1)?.label == [SourceRange(1, 3)])
        #expect(document.referenceSyntax(for: 1)?.destination == [SourceRange(7, 7)])
        #expect(document.nodes[1].range == SourceRange(0, 10))
    }
}
