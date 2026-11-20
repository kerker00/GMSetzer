import GMSetzer
import Testing

struct FrontMatterTests {
    static func parser(base: Profile = .commonMark, disabled: Set<String> = [], collect: Bool = true) -> MarkdownParser {
        MarkdownParser(profile: Profile(name: "frontmatter-test",
            extensions: base.extensions + [ExtensionConfiguration(FrontMatter.identifier)],
            disabledRules: base.disabledRules.union(disabled), ruleOrder: base.ruleOrder),
            extensions: [FrontMatter.implementation], collectSyntaxDetails: collect)
    }

    static func metadata(_ document: Document) throws -> FrontMatter {
        let index = try #require(document.nodes.firstIndex { $0.kind == FrontMatter.kind })
        return try #require(FrontMatter(document, at: index))
    }

    static let renderer = HTMLRenderer(hooks: [FrontMatter.kind: { _, _ in .replace("") }])

    @Test func yamlAndTomlKeepRawTextAndResumeNormalMarkdown() throws {
        for (fence, format, raw) in [("---", FrontMatter.Format.yaml, "title: Example\n"),
                                    ("+++", .toml, "title = \"Example\"\n")] {
            let source = fence + "\n" + raw + fence + "\n# Body\n"
            let document = try Self.parser().validated().parse(source)
            let metadata = try Self.metadata(document)
            #expect(metadata.format == format)
            #expect(metadata.rawText == raw)
            #expect(metadata.rawBytes == Array(raw.utf8))
            #expect(metadata.contentRange == SourceRange(4, 4 + raw.utf8.count))
            #expect(metadata.range == SourceRange(0, 8 + raw.utf8.count))
            #expect(document.children(of: 0).map { document.nodes[$0].kind } == [FrontMatter.kind, .heading])
            #expect(document.diagnostics.isEmpty)
            #expect(Self.renderer.render(document) == "<h1>Body</h1>\n")
        }
    }

    @Test func onlyTheOriginalFirstPhysicalLineCanStartFrontMatter() {
        for source in ["\n---\na: b\n---\n", "intro\n---\na: b\n---\n",
                       " ---\na: b\n---\n", "\t---\na: b\n---\n",
                       "> ---\n> a: b\n> ---\n", "- ---\n  a: b\n  ---\n",
                       "```\n---\na: b\n---\n```\n", "\u{FEFF}\n+++\na=1\n+++\n"] {
            let document = Self.parser().parse(source)
            #expect(!document.nodes.contains { $0.kind == FrontMatter.kind }, "\(source)")
            #expect(document.nodes == MarkdownParser().parse(source).nodes, "\(source)")
            #expect(document.source == Array(source.utf8))
        }
    }

    @Test func danglingOrMismatchedFencesFallBackWithoutSwallowingTheDocument() {
        for source in ["---\nvalue\n", "+++\nvalue\n", "---", "+++",
                       "---\nvalue\n+++\n", "+++\nvalue\n---\n", "---\nvalue\n...\n",
                       "---\nvalue\n--- extra\n"] {
            let document = Self.parser().parse(source)
            let plain = MarkdownParser().parse(source)
            #expect(!document.nodes.contains { $0.kind == FrontMatter.kind }, "\(source)")
            #expect(document.nodes == plain.nodes, "\(source)")
            #expect(document.diagnostics == plain.diagnostics)
            #expect(HTMLRenderer().render(document) == HTMLRenderer().render(plain))
        }
    }

    @Test func fencesAreExactlyThreeMarkersAtColumnZero() throws {
        for opening in ["----", "--- title", "---\u{00A0}", "++++", "+++ title"] {
            let closing = opening.hasPrefix("-") ? "---" : "+++"
            let source = opening + "\nvalue\n" + closing + "\n"
            #expect(!Self.parser().parse(source).nodes.contains { $0.kind == FrontMatter.kind })
        }
        let raw = " ---\n----\n--- extra\n+++\n"
        let document = Self.parser().parse("---\n" + raw + "---\n")
        #expect(try Self.metadata(document).rawText == raw)
        #expect(document.diagnostics.isEmpty)
    }

    @Test func trailingASCIIWhitespaceAndAllLineEndingsAreRetained() throws {
        for ending in ["\n", "\r\n", "\r"] {
            let opening = "--- \t" + ending
            let raw = "title: Example" + ending
            let source = opening + raw + "---\t "
            let document = Self.parser().parse(source)
            let metadata = try Self.metadata(document)
            #expect(metadata.rawText == raw)
            #expect(metadata.range.upperBound == source.utf8.count)
            #expect(metadata.contentRange == SourceRange(opening.utf8.count, opening.utf8.count + raw.utf8.count))
            let tokens = (document.tokens ?? []).filter { $0.role.hasPrefix("frontmatter.") }
            #expect(tokens.map(\.range) == [SourceRange(0, 3), metadata.contentRange,
                SourceRange(opening.utf8.count + raw.utf8.count, opening.utf8.count + raw.utf8.count + 3)])
        }
    }

    @Test func emptyMetadataKeepsAnInsertionRangeWithoutChildren() throws {
        for fence in ["---", "+++"] {
            let document = Self.parser().parse(fence + "\n" + fence)
            let metadata = try Self.metadata(document)
            let owner = try #require(document.nodes.firstIndex { $0.kind == FrontMatter.kind })
            #expect(metadata.rawBytes.isEmpty)
            #expect(metadata.rawText.isEmpty)
            #expect(metadata.contentRange == SourceRange(4, 4))
            #expect(document.nodes[owner].sourceSegments == [SourceRange(4, 4)])
            #expect(document.nodes[owner].firstChild == nil)
            #expect(document.tokens?.first { $0.role == "frontmatter.content" }?.range == SourceRange(4, 4))
        }
    }

    @Test func BOMUnicodeCRLFInvalidUTF8AndNULPreserveOriginalBytes() throws {
        let raw = Array("title: Ä😀\r\n".utf8) + [255, 0, 13, 10]
        let bytes = [UInt8(0xEF), 0xBB, 0xBF] + Array("---\r\n".utf8) + raw + Array("---\r\n# Body\n".utf8)
        let document = Self.parser().parse(bytes: bytes)
        let metadata = try Self.metadata(document)
        #expect(document.source == bytes)
        #expect(metadata.rawBytes == raw)
        #expect(metadata.rawText == String(decoding: raw, as: UTF8.self))
        #expect(metadata.range == SourceRange(3, 13 + raw.count))
        #expect(metadata.contentRange == SourceRange(8, 8 + raw.count))
        #expect(SourceIndex(document).utf16Offset(atUTF8Offset: metadata.contentRange.lowerBound) == 6)
        #expect(Self.renderer.render(document) == "<h1>Body</h1>\n")
    }

    @Test func formatsAreIndependentlyDisabledUsingExistingRuleControls() throws {
        for disabled: Set<String> in [[], ["frontmatter.yaml"], ["frontmatter.toml"], ["frontmatter.yaml", "frontmatter.toml"]] {
            let parser = try Self.parser(disabled: disabled).validated()
            for (fence, rule) in [("---", "frontmatter.yaml"), ("+++", "frontmatter.toml")] {
                let document = parser.parse(fence + "\nvalue\n" + fence + "\n")
                #expect(document.nodes.contains { $0.kind == FrontMatter.kind } == !disabled.contains(rule))
            }
        }
    }

    @Test func selectionIsExplicitAndStrictProfilesDoNotChange() {
        let source = "---\ntitle: Example\n---\n"
        for profile in [Profile.commonMark, .gfm] {
            let document = MarkdownParser(profile: profile, extensions: [FrontMatter.implementation]).parse(source)
            #expect(document.nodes == MarkdownParser(profile: profile).parse(source).nodes)
            #expect(!profile.extensions.contains { $0.identifier == FrontMatter.identifier })
            #expect(!document.nodes.contains { $0.kind == FrontMatter.kind })
        }
    }

    @Test func gfmBodyStillHasTablesTasksAndInlineSyntax() throws {
        let raw = "note = \"www.example.org ~~raw~~\"\n|not|markdown|\n"
        let source = "+++\n" + raw + "+++\n| a |\n| - |\n| b |\n\n- [x] task ~~done~~\n"
        let document = try Self.parser(base: .gfm).validated().parse(source)
        #expect(try Self.metadata(document).rawText == raw)
        #expect(document.nodes.filter { $0.kind == .table }.count == 1)
        #expect(document.nodes.filter { $0.kind == .taskListItem }.count == 1)
        #expect(document.nodes.filter { $0.kind == .strikethrough }.count == 1)
        #expect(document.nodes.filter { $0.kind == .link }.isEmpty)
        #expect(Self.renderer.render(document).contains("<table>"))
        #expect(Self.renderer.render(document).contains("<del>done</del>"))
    }

    @Test func metadataIsOpaqueToInlinesReferencesOutlineAndNativeAnalysis() throws {
        let source = "---\n# Hidden\n[link]: /hidden\ntitle: *raw*\ntrailing \t\n---\n# Visible\n\n[link]\n"
        let document = Self.parser().parse(source)
        #expect(document.nodes.filter { $0.kind == .referenceDefinition || $0.kind == .emphasis }.isEmpty)
        #expect(DocumentIndex(document).outline().count == 1)
        #expect(try NativeAnalyzer.analyze(document,
            configuration: NativeAnalysisConfiguration(rules: Set(NativeRule.allCases))).findings.isEmpty)
        #expect(Self.renderer.render(document) == "<h1>Visible</h1>\n<p>[link]</p>\n")
    }

    @Test func renderingPolicyStaysWithTheCallerAndFallbackRemainsEscaped() {
        let document = Self.parser().parse("---\n<script>alert(1)</script>\n---\n# Body\n")
        let fallback = HTMLRenderer(allowRawHTML: true).render(document)
        #expect(fallback.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(!fallback.contains("<script>"))
        #expect(Self.renderer.render(document) == "<h1>Body</h1>\n")
    }

    @Test func projectedChildParsersCannotRestartDocumentStartRecognition() {
        let kind = NodeKind("wrapper.block")
        let wrapper = MarkdownExtension("wrapper", nodeKinds: [kind], blockRules: [
            BlockRule("root", priority: 10, trigger: 45) { context in
                guard context.isDocumentStart else { return nil }
                let children = (0..<context.lineCount).compactMap { context.line(at: $0) }
                return BlockMatch(consumedLines: context.lineCount,
                    data: .custom(kind: kind, role: .block, attributes: [:]), children: children)
            },
        ])
        let profile = Profile(name: "wrapped", extensions: [ExtensionConfiguration("wrapper"), ExtensionConfiguration(FrontMatter.identifier)])
        let document = MarkdownParser(profile: profile, extensions: [wrapper, FrontMatter.implementation], collectSyntaxDetails: true)
            .parse("---\na: b\n---\n")
        #expect(document.nodes.filter { $0.kind == kind }.count == 1)
        #expect(!document.nodes.contains { $0.kind == FrontMatter.kind })
        #expect(document.nodes.contains { $0.kind == .thematicBreak })
        #expect(document.diagnostics.isEmpty)
    }

    @Test func typedViewRejectsWrongIndicesAndMalformedPayloads() throws {
        let plain = MarkdownParser().parse("# Heading\n")
        #expect(FrontMatter(plain, at: -1) == nil)
        #expect(FrontMatter(plain, at: plain.nodes.count) == nil)
        #expect(FrontMatter(plain, at: 1) == nil)
        for mode in 0..<3 {
            var builder = DocumentBuilder(source: Array("---\nx\n---\n".utf8))
            let owner = try builder.append(.custom(kind: FrontMatter.kind, role: .block,
                attributes: ["format": .string(mode == 0 ? "unknown" : "yaml")]), range: SourceRange(0, 10),
                sourceSegments: mode == 1 ? [] : [SourceRange(4, 6)])
            if mode == 2 { try builder.append(.text("x"), range: SourceRange(4, 5), to: owner) }
            #expect(FrontMatter(try builder.build(), at: owner) == nil)
        }
    }

    @Test func onlyOneFrontMatterBlockIsRecognised() throws {
        let document = Self.parser().parse("---\na: b\n---\n\n+++\nc=1\n+++\n")
        #expect(document.nodes.filter { $0.kind == FrontMatter.kind }.count == 1)
        #expect(try Self.metadata(document).rawText == "a: b\n")
        #expect(Self.renderer.render(document) == "<p>+++\nc=1\n+++</p>\n")
    }

    @Test func annotationModePreservesMetadataAndBody() throws {
        let source = "---\ntitle: Example\n---\n> - *body*\n"
        let on = Self.parser().parse(source)
        let off = Self.parser(collect: false).parse(source)
        #expect(on.nodes == off.nodes)
        #expect(on.diagnostics == off.diagnostics)
        #expect(on.customLeafFallbacks == off.customLeafFallbacks)
        #expect(try Self.metadata(on) == Self.metadata(off))
        #expect(off.tokens == nil)
        let owner = try #require(on.nodes.firstIndex { $0.kind == FrontMatter.kind })
        let tokens = (on.tokens ?? []).filter { $0.role.hasPrefix("frontmatter.") }
        #expect(tokens.map(\.role) == ["frontmatter.fence.open", "frontmatter.content", "frontmatter.fence.close"])
        #expect(tokens.allSatisfy { $0.owner == owner })
        #expect((on.tokens ?? []).contains { $0.role == "core.blockQuote.marker" })
        #expect((on.tokens ?? []).contains { $0.role == "core.emphasis.open" })
    }

    @Test func largeDanglingOpenerRetainsTheEntireDocument() {
        let source = "---\n" + String(repeating: "--- extra\n", count: 1_000)
        let document = Self.parser().parse(source)
        #expect(document.source == Array(source.utf8))
        #expect(!document.nodes.contains { $0.kind == FrontMatter.kind })
        #expect(document.nodes == MarkdownParser().parse(source).nodes)
    }
}
