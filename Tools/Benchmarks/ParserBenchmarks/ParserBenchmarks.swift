import Benchmark
import BenchmarkCorpus
import GMSetzer
import Markdown

/// Parse times of GMSetzer and of cmark-gfm (through swift-markdown) on the
/// same documents. The plan's target: GMSetzer at most twice cmark-gfm's
/// time, aiming for parity.
let benchmarks: @Sendable () -> Void = {
    for (label, bytes) in [("100 KB", 100_000), ("1 MB", 1_000_000), ("5 MB", 5_000_000)] {
        let text = Corpus.document(bytes: bytes)
        Benchmark("GMSetzer parse \(label)", configuration: .init(metrics: [.wallClock, .mallocCountTotal], maxDuration: .seconds(5))) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(MarkdownParser().parse(text))
            }
        }
        Benchmark("cmark-gfm parse \(label)", configuration: .init(metrics: [.wallClock, .mallocCountTotal], maxDuration: .seconds(5))) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(Markdown.Document(parsing: text))
            }
        }
    }
}
