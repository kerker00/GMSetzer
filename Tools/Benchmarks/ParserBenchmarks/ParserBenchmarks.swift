import Benchmark
import BenchmarkCorpus
import GMSetzer
import Markdown
import cmark_gfm

/// Parse times on the same documents:
/// - GMSetzer: syntax tree with source positions.
/// - cmark-gfm in C: the speed reference (CommonMark core, document freed
///   after parsing). Target: GMSetzer at most twice this time, aiming for
///   parity.
/// - swift-markdown: cmark-gfm plus Apple's Swift tree, what a Swift app
///   pays today.
let benchmarks: @Sendable () -> Void = {
    for (label, bytes) in [("100 KB", 100_000), ("1 MB", 1_000_000), ("5 MB", 5_000_000)] {
        let text = Corpus.document(bytes: bytes)
        Benchmark("GMSetzer parse \(label)", configuration: .init(metrics: [.wallClock, .mallocCountTotal], maxDuration: .seconds(5))) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(MarkdownParser().parse(text))
            }
        }
        Benchmark("cmark-gfm (C) parse \(label)", configuration: .init(metrics: [.wallClock, .mallocCountTotal], maxDuration: .seconds(5))) { benchmark in
            for _ in benchmark.scaledIterations {
                text.utf8CString.withUnsafeBufferPointer { buffer in
                    let document = cmark_parse_document(buffer.baseAddress, buffer.count - 1, CMARK_OPT_DEFAULT)
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
