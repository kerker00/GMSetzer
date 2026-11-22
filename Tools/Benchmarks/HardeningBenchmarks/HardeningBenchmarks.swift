import Benchmark
import BenchmarkCorpus
import GMSetzer
import cmark_gfm

private func measurement(_ source: [UInt8], workload: HardeningWorkload,
                         syntax: String) -> Benchmark.Configuration {
    .init(metrics: [.wallClock, .mallocCountTotal, .mallocBytesCount],
        tags: ["bytes": String(source.count), "corpus": workload.rawValue,
               "profile": workload.profileName, "syntax": syntax], maxDuration: .seconds(5))
}

/// Separate from the historical 72-case target. No input is parsed while
/// registering cases, including when the tool only lists/filter cases.
let benchmarks: @Sendable () -> Void = {
    for workload in HardeningWorkload.allCases {
        for (size, bytes) in [("16 KiB", 16_384), ("64 KiB", 65_536), ("256 KiB", 262_144)] {
            let source = workload.source(minimumBytes: bytes)
            for collect in [false, true] {
                let syntax = collect ? "on" : "off"
                let configuration = measurement(source, workload: workload, syntax: syntax)
                Benchmark("GMSetzer \(workload.rawValue) parse syntax-\(syntax) \(size)",
                          configuration: configuration) { benchmark in
                    for _ in benchmark.scaledIterations {
                        // Include parser/registry construction and document destruction.
                        let parser = try workload.parser(collectSyntaxDetails: collect)
                        blackHole(parser.parse(bytes: source))
                    }
                }
                if workload.usesExtensions {
                    Benchmark("GMSetzer \(workload.rawValue) parse-render syntax-\(syntax) \(size)",
                              configuration: configuration) { benchmark in
                        for _ in benchmark.scaledIterations {
                            let parser = try workload.parser(collectSyntaxDetails: collect)
                            blackHole(workload.renderer.render(parser.parse(bytes: source)))
                        }
                    }
                }
            }
            if !workload.usesExtensions {
                Benchmark("cmark-gfm (C) \(workload.rawValue) parse \(size)",
                          configuration: measurement(source, workload: workload, syntax: "off")) { benchmark in
                    for _ in benchmark.scaledIterations {
                        let parser = cmark_parser_new(CMARK_OPT_SOURCEPOS)
                        source.withUnsafeBufferPointer { buffer in
                            buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                                cmark_parser_feed(parser, $0, buffer.count)
                            }
                        }
                        let document = cmark_parser_finish(parser)
                        cmark_parser_free(parser)
                        blackHole(document)
                        cmark_node_free(document)
                    }
                }
            }
        }
    }
}
