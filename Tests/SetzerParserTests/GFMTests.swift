import GMSetzer
import Testing

/// GFM features as built-in core payloads: independent switches, exact
/// source ranges and the rendering policy selected by the profile.
struct GFMTests {
    static func only(_ feature: BuiltinExtension) -> MarkdownParser {
        MarkdownParser(profile: Profile(name: "gfm-\(feature.rawValue)", extensions: [ExtensionConfiguration(feature.rawValue)]))
    }

    static func allBut(_ feature: BuiltinExtension) -> MarkdownParser {
        MarkdownParser(profile: Profile(name: "gfm-without", extensions: BuiltinExtension.allCases
            .filter { $0 != feature }.map { ExtensionConfiguration($0.rawValue) }))
    }

    static func kinds(_ document: Document) -> Set<NodeKind> { Set(document.nodes.map(\.kind)) }

    @Test func profileSelectsBuiltinsWithoutImplementations() {
        #expect(MarkdownParser(profile: .gfm).configurationIssues.isEmpty)
        #expect(Profile.gfm.extensions.map(\.identifier) == BuiltinExtension.allCases.map(\.rawValue))
        let withOption = MarkdownParser(profile: Profile(name: "x", extensions: [ExtensionConfiguration("gfm.table", options: ["spans": .boolean(true)])]))
        #expect(withOption.configurationIssues.map(\.code) == [.unknownOption])
        let replaced = MarkdownParser(profile: Profile(name: "x", extensions: [ExtensionConfiguration("gfm.table")]),
                                      extensions: [MarkdownExtension("gfm.table", nodeKinds: [])])
        #expect(replaced.configurationIssues.map(\.code) == [.duplicateIdentifier])
    }

    @Test func everyFeatureSwitchesIndependently() {
        let samples: [(BuiltinExtension, String, NodeKind)] = [
            (.table, "| a |\n| - |\n", .table),
            (.taskList, "- [x] a\n", .taskListItem),
            (.strikethrough, "~~a~~\n", .strikethrough),
            (.autolink, "www.example.com\n", .link),
        ]
        for (feature, markdown, kind) in samples {
            #expect(Self.kinds(Self.only(feature).parse(markdown)).contains(kind), "\(feature) on")
            #expect(!Self.kinds(Self.allBut(feature).parse(markdown)).contains(kind), "\(feature) off")
            #expect(!Self.kinds(MarkdownParser().parse(markdown)).contains(kind), "\(feature) in CommonMark")
        }
        let raw = HTMLRenderer(allowRawHTML: true)
        #expect(raw.render(Self.only(.tagFilter).parse("<title>\n")) == "&lt;title>\n")
        #expect(raw.render(Self.allBut(.tagFilter).parse("<title>\n")) == "<title>\n")
        #expect(HTMLRenderer().render(Self.only(.tagFilter).parse("<title>\n")) == "&lt;title&gt;\n")
        let strong = "****a****\n"
        #expect(HTMLRenderer().render(Self.only(.collapseNestedStrong).parse(strong)) == "<p><strong>a</strong></p>\n")
        #expect(HTMLRenderer().render(Self.allBut(.collapseNestedStrong).parse(strong)) == "<p><strong><strong>a</strong></strong></p>\n")
        // The policy changes rendering only; the tree keeps both strong nodes.
        #expect(Self.only(.collapseNestedStrong).parse(strong).nodes.filter { $0.kind == .strong }.count == 2)
        #expect(MarkdownParser(profile: .gfm).parse("x").renderingPolicy == [.filtersDisallowedRawHTML, .collapsesNestedStrong])
        #expect(MarkdownParser().parse("x").renderingPolicy.isEmpty)
    }

    @Test func tableCellsMapToOriginalBytes() throws {
        let source = "| a \\| b | `c\\|d` |\n|:-|-:|\n| x |\n"
        let document = Self.only(.table).parse(source)
        let tableIndex = try #require(document.nodes.firstIndex { $0.kind == .table })
        #expect(document.nodes[tableIndex].data == .table(TableAttributes(alignments: [.left, .right])))
        let rows = document.children(of: tableIndex)
        #expect(rows.map { document.nodes[$0].data } == [.tableRow(isHeader: true), .tableRow(isHeader: false)])
        let header = document.children(of: rows[0])
        #expect(header.map { document.nodes[$0].data } == [.tableCell(alignment: .left), .tableCell(alignment: .right)])
        // The backslash before an escaped pipe is not part of the cell text.
        let text = try #require(document.children(of: header[0]).first)
        #expect(document.nodes[text].data == .text("a | b"))
        #expect(document.nodes[text].sourceSegments == [SourceRange(2, 4), SourceRange(5, 8)])
        let code = try #require(document.children(of: header[1]).first)
        #expect(document.nodes[code].data == .code("c|d"))
        let body = document.children(of: rows[1])
        #expect(body.count == 2)
        // A completing cell is empty, at the row's end, and has no alignment.
        #expect(document.nodes[body[1]].data == .tableCell(alignment: .none))
        #expect(document.nodes[body[1]].range.isEmpty)
        #expect(HTMLRenderer().render(document).contains("<td align=\"left\">x</td>\n<td></td>"))
    }

    @Test func tableSyntaxTokensAndPreamble() throws {
        let parser = MarkdownParser(profile: .gfm, collectSyntaxDetails: true)
        let document = parser.parse("[r]: /u\n|a|\n|-|\n")
        let tokens = try #require(document.tokens)
        #expect(tokens.filter { $0.role == "gfm.table.delimiterRow" }.map(\.range) == [SourceRange(12, 15)])
        #expect(tokens.filter { $0.role == "gfm.table.pipe" }.map(\.range) == [SourceRange(8, 9), SourceRange(10, 11)])
        // cmark-gfm keeps the lines before a header as paragraph text.
        #expect(!Self.kinds(document).contains(.referenceDefinition))
        #expect(HTMLRenderer().render(document).hasPrefix("<p>[r]: /u</p>\n<table>"))
        // Without a delimiter row the same lines define a reference.
        #expect(Self.kinds(parser.parse("[r]: /u\n|a|\n")).contains(.referenceDefinition))
    }

    @Test func taskListItemsFollowTheMarkerLine() throws {
        let document = MarkdownParser(profile: .gfm, collectSyntaxDetails: true).parse("- [ ] a\n- [X] b\n\n> - [x] c\n")
        let items = document.nodes.filter { $0.kind == .taskListItem }
        #expect(items.map(\.data) == [.taskListItem(checked: false), .taskListItem(checked: true)])
        #expect(document.tokens?.filter { $0.role == "gfm.tasklist.marker" }.map(\.range) == [SourceRange(2, 5), SourceRange(10, 13)])
        // cmark-gfm matches the checkbox pattern from the physical line start.
        #expect(document.nodes.contains { $0.data == .text("[x] c") })
        let html = HTMLRenderer().render(document)
        #expect(html.hasPrefix("<ul>\n<li><input disabled=\"\" type=\"checkbox\"> a</li>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> b</li>"))
        // The rest of the marker line is paragraph text, never another block.
        let heading = MarkdownParser(profile: .gfm).parse("- [ ] # not a heading\n")
        #expect(!Self.kinds(heading).contains(.heading))
        let outline = DocumentIndex(MarkdownParser(profile: .gfm).parse("- [ ] task\n\n  # Inside\n")).outline()
        #expect(outline.map(\.title) == ["Inside"])
    }

    @Test func strikethroughPairsEqualRuns() throws {
        let source = "~~a~~ ~b~ ~~~c~~~ ~d~~\n"
        let document = MarkdownParser(profile: .gfm, collectSyntaxDetails: true).parse(source)
        let struck = document.nodes.filter { $0.kind == .strikethrough }
        #expect(struck.map(\.range) == [SourceRange(0, 5), SourceRange(6, 9)])
        #expect(HTMLRenderer().render(document) == "<p><del>a</del> <del>b</del> ~~~c~~~ ~d~~</p>\n")
        #expect(document.tokens?.filter { $0.role.hasPrefix("gfm.strikethrough") }.map(\.range)
                == [SourceRange(0, 2), SourceRange(3, 5), SourceRange(6, 7), SourceRange(8, 9)])
    }

    @Test func autolinksKeepSourceSpelling() throws {
        let source = "see www.x.yz/a). and http://a.b and foo@bar.baz. [www.no.link](u)\n"
        let document = MarkdownParser(profile: .gfm, collectSyntaxDetails: true).parse(source)
        let links = document.nodes.filter { $0.kind == .link }
        let bytes = Array(source.utf8)
        #expect(links.map { String(decoding: bytes[$0.range.lowerBound..<$0.range.upperBound], as: UTF8.self) }
                == ["www.x.yz/a", "http://a.b", "foo@bar.baz", "[www.no.link](u)"])
        #expect(links.map(\.data) == [.link(destination: "http://www.x.yz/a", title: nil), .link(destination: "http://a.b", title: nil),
                                      .link(destination: "mailto:foo@bar.baz", title: nil), .link(destination: "u", title: nil)])
        #expect(document.tokens?.filter { $0.role == "gfm.autolink" }.count == 3)
        // An escaped '@' is still text to the email matcher, as in cmark-gfm.
        let escaped = MarkdownParser(profile: .gfm).parse("a\\@b.cd\n")
        #expect(escaped.nodes.contains { $0.data == .link(destination: "mailto:a@b.cd", title: nil) })
    }

    @Test func tableStructureIsValidated() throws {
        let source = Array("x".utf8)
        var builder = DocumentBuilder(source: source)
        let table = try builder.append(.table(TableAttributes(alignments: [.none])), range: SourceRange(0, 1))
        try builder.append(.paragraph, range: SourceRange(0, 1), to: table)
        #expect(throws: DocumentError.self) { try builder.build() }
        var empty = DocumentBuilder(source: source)
        try empty.append(.table(TableAttributes(alignments: [])), range: SourceRange(0, 1))
        #expect(throws: DocumentError.invalidPayload(node: 1)) { try empty.build() }
        var loose = DocumentBuilder(source: source)
        try loose.append(.tableCell(alignment: .none), range: SourceRange(0, 1))
        #expect(throws: DocumentError.self) { try loose.build() }
    }
}
