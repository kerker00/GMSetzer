import Benchmark
import BenchmarkCorpus
import GMSetzer
import Markdown
import cmark_gfm
import cmark_gfm_extensions

private func measurement(_ text: String, corpus: String) -> Benchmark.Configuration {
    .init(metrics: [.wallClock, .mallocCountTotal, .mallocBytesCount],
          tags: ["bytes": String(text.utf8.count), "corpus": corpus], maxDuration: .seconds(5))
}

/// Parse times on the same documents:
/// - GMSetzer: syntax tree with source positions.
/// - cmark-gfm in C: separate core and GFM references with source positions,
///   document freed after parsing. Compare each GMSetzer profile with the
///   corresponding C configuration.
/// - swift-markdown: contextual app comparison; its fixed feature set and
///   smart punctuation differ from both profiles.
let benchmarks: @Sendable () -> Void = {
    cmark_gfm_core_extensions_ensure_registered()
    for (label, bytes) in [("100 KB", 100_000), ("1 MB", 1_000_000), ("5 MB", 5_000_000)] {
        let text = Corpus.document(bytes: bytes)
        for (mode, profile) in [("CommonMark", Profile.commonMark), ("GFM", Profile.gfm)] {
            Benchmark("GMSetzer \(mode) parse \(label)", configuration: measurement(text, corpus: "mixed-v1")) { benchmark in
                for _ in benchmark.scaledIterations {
                    blackHole(MarkdownParser(profile: profile).parse(text))
                }
            }
            Benchmark("cmark-gfm (C) \(mode) parse \(label)", configuration: measurement(text, corpus: "mixed-v1")) { benchmark in
                for _ in benchmark.scaledIterations {
                    let parser = cmark_parser_new(CMARK_OPT_SOURCEPOS)
                    if profile == .gfm {
                        for name in ["table", "tasklist", "strikethrough", "autolink", "tagfilter"] {
                            cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension(name))
                        }
                    }
                    text.withCString { buffer in
                        cmark_parser_feed(parser, buffer, text.utf8.count)
                    }
                    let document = cmark_parser_finish(parser)
                    cmark_parser_free(parser)
                    blackHole(document)
                    cmark_node_free(document)
                }
            }
        }
        Benchmark("swift-markdown parse \(label)", configuration: measurement(text, corpus: "mixed-v1")) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(Markdown.Document(parsing: text))
            }
        }
        let document = MarkdownParser().parse(text)
        Benchmark("GMSetzer validate \(label)", configuration: measurement(text, corpus: "mixed-v1")) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(try Document(source: document.source, nodes: document.nodes,
                    diagnostics: document.diagnostics, customLeafFallbacks: document.customLeafFallbacks))
            }
        }
        let renderer = HTMLRenderer()
        Benchmark("GMSetzer render \(label)", configuration: measurement(text, corpus: "mixed-v1")) { benchmark in
            for _ in benchmark.scaledIterations { blackHole(renderer.render(document)) }
        }
        // Isolated reconstruction probes. These are additive microbenchmarks,
        // not an attribution or a subtraction from total parser timings.
        let textRanges = document.nodes.filter { $0.kind == .text }.map(\.range)
        Benchmark("GMSetzer text reconstruction \(label)", configuration: measurement(text, corpus: "mixed-v1")) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(textRanges.map { String(decoding: document.source[$0.lowerBound..<$0.upperBound], as: UTF8.self) })
            }
        }
        let segments = document.nodes.map(\.sourceSegments)
        Benchmark("GMSetzer segment reconstruction \(label)", configuration: measurement(text, corpus: "mixed-v1")) { benchmark in
            for _ in benchmark.scaledIterations {
                // Iterating/re-appending forces distinct arrays rather than COW copies.
                blackHole(segments.map { ranges -> [SourceRange] in
                    var copy: [SourceRange] = []
                    copy.reserveCapacity(ranges.count)
                    for range in ranges { copy.append(range) }
                    return copy
                })
            }
        }
        let referenceText = Corpus.referenceDocument(bytes: bytes)
        for collect in [false, true] {
            let parser = MarkdownParser(collectSyntaxDetails: collect)
            let mode = collect ? "on" : "off"
            Benchmark("GMSetzer reference syntax \(mode) \(label)",
                      configuration: measurement(referenceText, corpus: "references-v1")) { benchmark in
                for _ in benchmark.scaledIterations { blackHole(parser.parse(referenceText)) }
            }
        }
        Benchmark("cmark-gfm (C) references \(label)",
                  configuration: measurement(referenceText, corpus: "references-v1")) { benchmark in
            for _ in benchmark.scaledIterations {
                referenceText.withCString { input in
                    let root = cmark_parse_document(input, referenceText.utf8.count, CMARK_OPT_SOURCEPOS)
                    blackHole(root)
                    cmark_node_free(root)
                }
            }
        }
    }
}
