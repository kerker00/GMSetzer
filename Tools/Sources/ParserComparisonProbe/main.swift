import BenchmarkCorpus
import Dispatch
import Foundation
import GMSetzer
import cmark_gfm
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Original comparison adapter. cmark-gfm comes from the existing pinned
// swift-cmark development dependency; no foreign parser enters the library.
struct ProbeError: Error { let message: String }

@inline(never)
func operation(_ name: String, mode: String, text: String, emit: Bool = false) throws -> (Int, String?) {
    if name == "gmsetzer" {
        let document = MarkdownParser().parse(text)
        if mode == "parse" { return (document.nodes.count, nil) }
        let html = HTMLRenderer.conformance.render(document)
        return (html.utf8.count, emit ? html : nil)
    }
    guard name == "cmark" else { throw ProbeError(message: "Unknown parser") }
    let parser = cmark_parser_new(CMARK_OPT_SOURCEPOS)!
    text.withCString { cmark_parser_feed(parser, $0, text.utf8.count) }
    guard let document = cmark_parser_finish(parser) else {
        cmark_parser_free(parser)
        throw ProbeError(message: "cmark parse failed")
    }
    cmark_parser_free(parser)
    defer { cmark_node_free(document) }
    if mode == "parse" { return (Int(cmark_node_get_type(document).rawValue) + 1, nil) }
    guard let html = cmark_render_html(document, CMARK_OPT_UNSAFE, nil) else {
        throw ProbeError(message: "cmark render failed")
    }
    defer { free(html) }
    return (strlen(html), emit ? String(cString: html) : nil)
}

let arguments = CommandLine.arguments
if arguments.count == 3 && arguments[1] == "corpus" {
    let directory = URL(fileURLWithPath: arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for size in [100_000, 1_000_000, 5_000_000] {
        try Data(Corpus.document(bytes: size).utf8).write(to: directory.appendingPathComponent("mixed-\(size).md"))
    }
} else {
    guard arguments.count == 6, ["parse", "html", "emit"].contains(arguments[2]),
          let iterations = Int(arguments[5]), (1...100_000).contains(iterations),
          let text = String(data: try Data(contentsOf: URL(fileURLWithPath: arguments[3])), encoding: .utf8),
          arguments[4] == "commonmark" else {
        throw ProbeError(message: "Usage: ParserComparisonProbe parser parse|html|emit file commonmark iterations")
    }
    let name = arguments[1], mode = arguments[2]
    if mode == "emit" {
        let result = try operation(name, mode: "html", text: text, emit: true)
        FileHandle.standardOutput.write(Data(result.1!.utf8))
    } else {
        for _ in 0..<3 { _ = try operation(name, mode: mode, text: text) }
        var observed = 0
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations { observed &+= try operation(name, mode: mode, text: text).0 }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        print("{\"elapsed_ns\":\(elapsed),\"iterations\":\(iterations),\"observed\":\(observed)}")
    }
}
