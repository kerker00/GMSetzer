import Benchmark
import BenchmarkCorpus
import GMSetzer
import Markdown
import cmark_gfm
import cmark_gfm_extensions

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
            Benchmark("GMSetzer \(mode) parse \(label)", configuration: .init(metrics: [.wallClock, .mallocCountTotal], maxDuration: .seconds(5))) { benchmark in
                for _ in benchmark.scaledIterations {
                    blackHole(MarkdownParser(profile: profile).parse(text))
                }
            }
            Benchmark("cmark-gfm (C) \(mode) parse \(label)", configuration: .init(metrics: [.wallClock, .mallocCountTotal], maxDuration: .seconds(5))) { benchmark in
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
        Benchmark("swift-markdown parse \(label)", configuration: .init(metrics: [.wallClock, .mallocCountTotal], maxDuration: .seconds(5))) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(Markdown.Document(parsing: text))
            }
        }
    }
}
