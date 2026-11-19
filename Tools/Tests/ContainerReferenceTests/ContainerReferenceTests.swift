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
    @Test func leadingBOMCombinationsMatchCmark() {
        let renderer = HTMLRenderer(allowRawHTML: true, preserveHTMLComments: true)
        for body in ["", "\r\n", "# Title\r\n", "> quote\n", "- item\n", "\tcode\n",
                     "```\nbody\n```\n", "<div>\nbody\n", "[a]: /u\n\nbody\n", "\u{FEFF}# title\n"] {
            let source = "\u{FEFF}" + body
            #expect(renderer.render(MarkdownParser().parse(source)) == Self.reference(source, renderOptions: CMARK_OPT_UNSAFE))
        }
    }

    static let fragments = [
        "p", "q", "", "> p", ">", "> > p", "> - p", "- p", "-", "- q",
        "  q", "  - q", "    q", "\tp", "-\tq", "-     q", "  > q", "  >",
        "1. p", "2. q", "2) q", "0. q", "999999999. q", "1000000000. q",
        "***", "---", "===", "# q", "```", "~~~", "    - q",
    ]

    static func reference(_ text: String, renderOptions: Int32 = CMARK_OPT_DEFAULT) -> String {
        text.withCString { input in
            let document = cmark_parse_document(input, text.utf8.count, CMARK_OPT_DEFAULT)!
            defer { cmark_node_free(document) }
            let html = cmark_render_html(document, renderOptions, nil)!
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

extension ContainerReferenceTests {
    @Test func generatedHTMLAndReferenceBlocksMatchCmark() throws {
        let fragments = ["p", "", "- p", "-", "  body", "> p", ">", "  > q", "[label]: /u", "[label]:", "/v",
                         "<empty>", "'title'", "\"title\" junk", "[", "label", "]: /u", "<div>", "</div>",
                         "<!--", "done -->", "<?pi", "?>", "<!DOCTYPE html>", "<![CDATA[", "]]>",
                         "<custom bool a='b'>", "<script>", "</script>", "```"]
        // Unique labels keep this a block-phase comparison: a repeated valid
        // definition must not turn a later malformed occurrence into an inline link.
        func document(_ fragments: [String]) -> String {
            fragments.enumerated().map { index, fragment in
                fragment.replacingOccurrences(of: "[label]", with: "[r\(index)]") + "\n"
            }.joined()
        }
        var documents: [String] = []
        for first in fragments {
            for second in fragments { documents.append(document([first, second])) }
        }
        var state: UInt64 = 493
        for _ in 0..<1_024 {
            var input: [String] = []
            for _ in 0..<6 {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                input.append(fragments[Int((state >> 32) % UInt64(fragments.count))])
            }
            documents.append(document(input))
        }
        let parser = MarkdownParser()
        var failures = 0
        for text in documents {
            let actual = Self.blockShape(parser.parse(text))
            let expected = Self.referenceBlockShape(text)
            if actual != expected {
                failures += 1
                if failures <= 20 {
                    let data = try JSONSerialization.data(withJSONObject: ["markdown": text, "actual": actual.joined(separator: " | "), "expected": expected.joined(separator: " | ")], options: [.sortedKeys])
                    print("REFERENCE_FAILURE \(String(decoding: data, as: UTF8.self))")
                }
            }
        }
        #expect(failures == 0, "\(failures) of \(documents.count) HTML/reference documents differ from cmark")
    }

    /// Ignore inline children until M2, but compare every block kind, nesting,
    /// list property and literal code/HTML content. References are definitions,
    /// not rendered C AST nodes, so their source values have dedicated tests.
    static func blockShape(_ document: Document) -> [String] {
        var result: [String] = []
        var pending = [(0, 0)]
        while let (index, depth) = pending.popLast() {
            let node = document.nodes[index]
            switch node.data {
            case .referenceDefinition: continue
            case .paragraph: result.append("\(depth):" + "paragraph"); continue
            case .heading(let level): result.append("\(depth):" + "heading:\(level)"); continue
            case .codeBlock(let info, let literal): result.append("\(depth):" + "code_block:\(info ?? ""):\(literal)"); continue
            case .htmlBlock(let html): result.append("\(depth):" + "html_block:\(html.literal)"); continue
            case .blockQuote: result.append("\(depth):" + "block_quote")
            case .listItem: result.append("\(depth):" + "item")
            case .thematicBreak: result.append("\(depth):" + "thematic_break")
            case .list(let attributes):
                let style: String
                switch attributes.style {
                case .bullet: style = "bullet"
                case .ordered(let start, let delimiter): style = "ordered:\(start):\(delimiter == 41 ? ")" : ".")"
                }
                result.append("\(depth):" + "list:\(style):\(attributes.isTight)")
            default: result.append("\(depth):" + node.kind.name)
            }
            pending.append(contentsOf: document.children(of: index).reversed().map { ($0, depth + 1) })
        }
        return result
    }

    static func referenceBlockShape(_ text: String) -> [String] {
        text.withCString { input in
            let root = cmark_parse_document(input, text.utf8.count, CMARK_OPT_DEFAULT)!
            defer { cmark_node_free(root) }
            var result: [String] = []
            var pending = [(root, 0)]
            while let (node, depth) = pending.popLast() {
                let kind = String(cString: cmark_node_get_type_string(node))
                switch kind {
                case "paragraph": result.append("\(depth):" + kind); continue
                case "heading": result.append("\(depth):" + "heading:\(cmark_node_get_heading_level(node))"); continue
                case "code_block":
                    let info = cmark_node_get_fence_info(node).map { String(cString: $0) } ?? ""
                    result.append("\(depth):" + "code_block:\(info):\(String(cString: cmark_node_get_literal(node)))"); continue
                case "html_block": result.append("\(depth):" + "html_block:\(String(cString: cmark_node_get_literal(node)))"); continue
                case "list":
                    let style: String
                    if cmark_node_get_list_type(node) == CMARK_BULLET_LIST { style = "bullet" }
                    else { style = "ordered:\(cmark_node_get_list_start(node)):\(cmark_node_get_list_delim(node) == CMARK_PAREN_DELIM ? ")" : ".")" }
                    result.append("\(depth):" + "list:\(style):\(cmark_node_get_list_tight(node) != 0)")
                default: result.append("\(depth):" + kind)
                }
                var child = cmark_node_last_child(node)
                while let current = child { pending.append((current, depth + 1)); child = cmark_node_previous(current) }
            }
            return result
        }
    }
}
