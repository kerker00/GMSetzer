import Foundation
import GMSetzer
import Testing
import cmark_gfm
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Small, deterministic documents made from our own plain-text block fragments.
/// No inline features or raw HTML: those are later parser milestones. The
/// pinned C implementation is a behavioral oracle, not a library dependency.
struct ContainerReferenceTests {
    static let fragments = [
        "p", "q", "", "> p", ">", "> > p", "> - p", "- p", "-", "- q",
        "  q", "  - q", "    q", "\tp", "-\tq", "-     q", "  > q", "  >",
        "1. p", "2. q", "2) q", "0. q", "999999999. q", "1000000000. q",
        "***", "---", "===", "# q", "```", "~~~", "    - q",
    ]

    static func reference(_ text: String) -> String {
        text.withCString { input in
            let document = cmark_parse_document(input, text.utf8.count, CMARK_OPT_DEFAULT)!
            defer { cmark_node_free(document) }
            let html = cmark_render_html(document, CMARK_OPT_DEFAULT, nil)!
            defer { free(html) }
            return String(cString: html)
        }
    }

    @Test func generatedContainerCombinationsMatchCmark() throws {
        var documents: [String] = []
        for first in Self.fragments {
            for second in Self.fragments { documents.append(first + "\n" + second + "\n") }
        }
        var state: UInt64 = 2026
        for _ in 0..<1_024 {
            var text = ""
            for _ in 0..<6 {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                text += Self.fragments[Int((state >> 32) % UInt64(Self.fragments.count))] + "\n"
            }
            documents.append(text)
        }
        let parser = MarkdownParser()
        let renderer = HTMLRenderer()
        var failures: [[String: String]] = []
        for text in documents {
            let actual = renderer.render(parser.parse(text))
            let expected = Self.reference(text)
            if actual != expected { failures.append(["markdown": text, "actual": actual, "expected": expected]) }
        }
        for failure in failures.prefix(20) {
            let data = try JSONSerialization.data(withJSONObject: failure, options: [.sortedKeys])
            print("REFERENCE_FAILURE \(String(decoding: data, as: UTF8.self))")
        }
        let failureCount = failures.count
        #expect(failureCount == 0, "\(failureCount) of \(documents.count) generated container documents differ from cmark")
    }
}
