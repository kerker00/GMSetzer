import Foundation
import GMSetzer

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private func check(_ value: Bool, _ message: String) throws {
    if !value { throw CheckFailure(description: message) }
}

@main
struct PortabilityProbe {
    struct Example: Decodable {
        let markdown: String
        let html: String
        let example: Int
    }

    struct Baseline: Decodable {
        let commonmark: [Int]
        let gfm: [Int]
    }

    static func load<T: Decodable>(_ type: T.Type, _ directory: URL, _ name: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: directory.appendingPathComponent(name)))
    }

    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw CheckFailure(description: "Usage: PortabilityProbe <spec-resources-directory>")
        }
        let resources = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let baseline = try load(Baseline.self, resources, "baseline.json")
        let renderer = HTMLRenderer(allowRawHTML: true, preserveHTMLComments: true)
        for (name, count, profile, protected) in [
            ("commonmark-0.31.2.json", 652, Profile.commonMark, baseline.commonmark),
            ("gfm-0.29.json", 672, Profile.gfm, baseline.gfm),
        ] {
            let examples = try load([Example].self, resources, name)
            try check(examples.count == count, "Unexpected fixture count: \(name)")
            let ids = Set(examples.map(\.example))
            try check(ids.count == count && Set(protected).count == protected.count && Set(protected).isSubset(of: ids),
                      "Invalid fixture/baseline IDs: \(name)")
            let parser = MarkdownParser(profile: profile)
            let passing = Set(examples.compactMap { example in
                renderer.render(parser.parse(example.markdown)) == example.html ? example.example : nil
            })
            let lost = Set(protected).subtracting(passing).sorted()
            try check(lost.isEmpty, "Regressed protected IDs in \(name): \(lost)")
            print("\(name): \(passing.count)/\(count) exact HTML, \(protected.count) protected IDs retained")
        }

        let bomText = "\u{FEFF}# Grüße 😀\r\n"
        let bom = MarkdownParser().parse(bomText)
        try check(bom.source == Array(bomText.utf8) && bom.nodes[1].range.lowerBound == 3,
                  "BOM/original-byte provenance")
        try check(HTMLRenderer().render(bom) == "<h1>Grüße 😀</h1>\n", "BOM heading")
        let wrapped = HTMLRenderer(hooks: [.list: { _, _ in .wrapChildren(open: "<ul>\n", close: "</ul>\n") }])
        for text in ["- one\n- two\n", "- one\n\n- two\n", "> - one\n> - two\n"] {
            let document = MarkdownParser().parse(text)
            try check(wrapped.render(document) == HTMLRenderer().render(document), "List wrapper semantics")
        }
        let custom = NodeKind("probe.leaf")
        let implementation = MarkdownExtension("probe", blockRules: [BlockRule("twoLines", trigger: 58) { context in
            guard let next = context.line(at: context.lineIndex + 1) else { return nil }
            return BlockMatch(consumedLines: 2, data: .custom(kind: custom, role: .block, attributes: [:]),
                              sourceSegments: [next.contentRange])
        }])
        let parser = MarkdownParser(profile: Profile(name: "probe", extensions: [ExtensionConfiguration("probe")]),
                                    extensions: [implementation])
        let projected = parser.parse(">\t:::\r\n>\tbody\r\n")
        try check(HTMLRenderer().render(projected) == "<blockquote>\n  :::\n  body\n</blockquote>\n",
                  "Projected fallback/tab/CRLF")
        let raw: [UInt8] = [35, 32, 0xFF, 0, 13, 10]
        let replaced = MarkdownParser().parse(bytes: raw)
        try check(replaced.source == raw && HTMLRenderer().render(replaced) == "<h1>��</h1>\n", "Invalid UTF-8/NUL")
        do {
            _ = try Document(source: [], nodes: [])
            throw CheckFailure(description: "Invalid root was accepted")
        } catch DocumentError.invalidRoot { }
        let valid = MarkdownParser().parse("# x\n")
        do {
            _ = try Document(source: valid.source, nodes: valid.nodes, customLeafFallbacks: [Int.max: "invalid"])
            throw CheckFailure(description: "Invalid fallback owner was accepted")
        } catch DocumentError.invalidFallback(node: Int.max) { }
        print("PORTABILITY_PROBE_PASSED: protected spec baselines and targeted source/render/validation checks")
        print("This probe does not replace the full Swift Testing suite, Tools comparisons or performance measurements.")
    }
}
