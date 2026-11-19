import Foundation
import GMSetzer
import Testing

/// Every example of the CommonMark and GFM specifications. The suite never
/// lets the number of passing examples fall below `baseline.json`, so
/// progress can only ratchet up.
struct SpecTests {
    struct Example: Decodable {
        let markdown: String
        let html: String
        let example: Int
        let section: String?
        let `extension`: String?
    }

    struct Baseline: Decodable {
        let commonmark: Int
        let gfm: Int
    }

    static func resource(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources"))
        return try Data(contentsOf: url)
    }

    static func examples(_ name: String) throws -> [Example] {
        try JSONDecoder().decode([Example].self, from: resource(name))
    }

    /// Runs the examples and returns the numbers of the failing ones.
    static func failures(_ examples: [Example], profile: Profile) -> [Int] {
        let parser = MarkdownParser(profile: profile)
        let renderer = HTMLRenderer()
        return examples.filter { renderer.render(parser.parse($0.markdown)) != $0.html }.map(\.example)
    }

    @Test func commonMarkExamplesNeverRegress() throws {
        let examples = try Self.examples("commonmark-0.31.2")
        #expect(examples.count == 652)
        let baseline = try JSONDecoder().decode(Baseline.self, from: Self.resource("baseline"))
        let passed = examples.count - Self.failures(examples, profile: .commonMark).count
        print("CommonMark 0.31.2: \(passed)/\(examples.count) examples pass (baseline \(baseline.commonmark))")
        #expect(passed >= baseline.commonmark)
    }

    @Test func gfmExamplesNeverRegress() throws {
        let examples = try Self.examples("gfm-0.29").filter { $0.extension != "disabled" }
        #expect(examples.count == 670)
        let baseline = try JSONDecoder().decode(Baseline.self, from: Self.resource("baseline"))
        let passed = examples.count - Self.failures(examples, profile: .gfm).count
        print("GFM 0.29: \(passed)/\(examples.count) examples pass (baseline \(baseline.gfm))")
        #expect(passed >= baseline.gfm)
    }
}
