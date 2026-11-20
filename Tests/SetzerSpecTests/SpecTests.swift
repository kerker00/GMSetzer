import Foundation
import GMSetzer
import Testing

/// Every example of the CommonMark and GFM specifications. The suite
/// protects each passing example recorded in `baseline.json`. A newly
/// passing example cannot hide a regression in a different example.
struct SpecTests {
    struct Example: Decodable {
        let markdown: String
        let html: String
        let example: Int
        let section: String?
        let `extension`: String?
    }

    struct Baseline: Decodable {
        let commonmark: [Int]
        let gfm: [Int]
    }

    static func resource(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources"))
        return try Data(contentsOf: url)
    }

    static func examples(_ name: String) throws -> [Example] {
        try JSONDecoder().decode([Example].self, from: resource(name))
    }

    /// Runs the examples and returns the numbers of the passing ones.
    static func passingExamples(_ examples: [Example], profile: Profile,
                                perExample: ((Example) -> Profile)? = nil) -> [Int] {
        let parser = MarkdownParser(profile: profile)
        // Trusted fixtures explicitly request specification output. Production
        // rendering retains escaped raw HTML and omitted comments by default.
        let renderer = HTMLRenderer.conformance
        let diagnose = ProcessInfo.processInfo.environment["GMSETZER_SPEC_DIAGNOSTICS"] == "1"
        return examples.compactMap { example in
            let actual = renderer.render((perExample.map { MarkdownParser(profile: $0(example)) } ?? parser).parse(example.markdown))
            if actual == example.html { return example.example }
            if diagnose {
                let report: [String: Any] = ["profile": profile.name, "example": example.example,
                    "section": example.section ?? "", "markdown": example.markdown,
                    "expected": example.html, "actual": actual]
                if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
                   let text = String(data: data, encoding: .utf8) { print("SPEC_FAILURE \(text)") }
            }
            return nil
        }
    }

    static func regressions(baseline: [Int], passing: [Int]) -> [Int] {
        Set(baseline).subtracting(passing).sorted()
    }

    @discardableResult
    static func check(_ examples: [Example], profile: Profile, baseline: [Int],
                      perExample: ((Example) -> Profile)? = nil) -> [Int] {
        let ids = Set(examples.map(\.example))
        #expect(ids.count == examples.count, "Example IDs must be unique")
        #expect(Set(baseline).count == baseline.count, "Baseline IDs must be unique")
        #expect(Set(baseline).isSubset(of: ids), "Baseline must refer to existing examples")
        let passing = passingExamples(examples, profile: profile, perExample: perExample)
        let regressed = regressions(baseline: baseline, passing: passing)
        print("\(profile.name): \(passing.count)/\(examples.count) examples pass (\(baseline.count) protected)")
        let newlyPassing = Set(passing).subtracting(baseline).sorted()
        if !newlyPassing.isEmpty { print("\(profile.name) new passing IDs: \(newlyPassing)") }
        #expect(regressed.isEmpty, "Regressed example IDs: \(regressed)")
        return passing
    }

    @Test func aNewPassCannotHideARegression() {
        #expect(Self.regressions(baseline: [1, 2], passing: [2, 3]) == [1])
        #expect(Self.regressions(baseline: [1, 2], passing: [1, 2, 3]).isEmpty)
    }

    @Test func commonMarkExamplesNeverRegress() throws {
        let examples = try Self.examples("commonmark-0.31.2")
        #expect(examples.count == 652)
        let baseline = try JSONDecoder().decode(Baseline.self, from: Self.resource("baseline"))
        let passing = Self.check(examples, profile: .commonMark, baseline: baseline.commonmark)
        #expect(passing.count == 652, "M2 requires complete exact CommonMark conformance")
    }

    /// The GFM corpus is defined per example, as upstream's spec runner
    /// does: core examples run without extensions, an extension example with
    /// exactly its extension. GitHub's nested-strong rendering is part of the
    /// cmark-gfm core renderer and always applies. Upstream marks the task
    /// list examples "disabled"; GMSetzer requires them with the task list.
    static func gfmProfile(for example: Example) -> Profile {
        var selected: [BuiltinExtension] = [.collapseNestedStrong]
        switch example.extension {
        case "table": selected.append(.table)
        case "strikethrough": selected.append(.strikethrough)
        case "autolink": selected.append(.autolink)
        case "tagfilter": selected.append(.tagFilter)
        case "disabled": selected.append(.taskList)
        default: break
        }
        return Profile(name: "gfm", extensions: selected.map { ExtensionConfiguration($0.rawValue) })
    }

    @Test func gfmExamplesNeverRegress() throws {
        let examples = try Self.examples("gfm-0.29")
        #expect(examples.count == 672)
        let baseline = try JSONDecoder().decode(Baseline.self, from: Self.resource("baseline"))
        let passing = Self.check(examples, profile: .gfm, baseline: baseline.gfm, perExample: Self.gfmProfile)
        #expect(passing.count == 672, "M4 requires the complete pinned GFM corpus")
    }

    @Test func gfmCorpusIncludesTaskListsAndTagFiltering() throws {
        let examples = try Self.examples("gfm-0.29")
        let taskLists = examples.filter { $0.section == "Task list items (extension)" }
        #expect(taskLists.map(\.example) == [279, 280])
        #expect(taskLists.allSatisfy { $0.html.contains("type=\"checkbox\"") })
        #expect(examples.contains { $0.extension == "tagfilter" })
    }

    @Test func syntaxCollectionPreservesEverySpecificationTreeAndHTML() throws {
        for (name, gfm) in [("commonmark-0.31.2", false), ("gfm-0.29", true)] {
            for example in try Self.examples(name) {
                let profile = gfm ? Self.gfmProfile(for: example) : .commonMark
                let off = MarkdownParser(profile: profile).parse(example.markdown)
                let on = MarkdownParser(profile: profile, collectSyntaxDetails: true).parse(example.markdown)
                #expect(on.source == off.source, "\(name) example \(example.example)")
                #expect(on.nodes == off.nodes, "\(name) example \(example.example)")
                #expect(on.diagnostics == off.diagnostics, "\(name) example \(example.example)")
                #expect(on.customLeafFallbacks == off.customLeafFallbacks)
                #expect(on.tokens != nil)
                #expect(HTMLRenderer.conformance.render(on) == example.html, "\(name) example \(example.example)")
                let markers = (on.tokens ?? []).filter { $0.role == "core.blockQuote.marker" || $0.role == "core.list.marker" }
                #expect(Set(markers).count == markers.count, "\(name) example \(example.example)")
            }
        }
    }

    @Test func referenceDefinitionSectionsHaveTheRequiredBlockShapes() throws {
        let expected = [192: 1, 193: 1, 194: 1, 195: 1, 196: 1, 197: 0, 198: 1, 199: 0,
                        200: 1, 201: 0, 202: 1, 203: 1, 204: 2, 205: 1, 206: 1, 207: 1,
                        208: 1, 209: 0, 210: 1, 211: 0, 212: 0, 213: 0, 214: 1, 215: 1,
                        216: 1, 217: 3, 218: 1]
        for example in try Self.examples("commonmark-0.31.2") where expected[example.example] != nil {
            let document = MarkdownParser(collectSyntaxDetails: true).parse(example.markdown)
            let references = document.nodes.filter { $0.kind == .referenceDefinition }
            #expect(references.count == expected[example.example], "Reference block shape in example \(example.example)")
            #expect(document.tokens != nil)
            #expect(document.tokens?.filter { $0.role.hasPrefix("core.reference.") }.allSatisfy { document.nodes[$0.owner].kind == .referenceDefinition } == true)
        }
    }
}
