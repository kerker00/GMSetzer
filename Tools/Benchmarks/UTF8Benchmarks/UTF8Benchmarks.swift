import Benchmark
import BenchmarkCorpus
import GMSetzer
import cmark_gfm

let benchmarks: @Sendable () -> Void = {
    for workload in UTF8Workload.allCases {
        for (size, bytes) in [("16 KiB", 16_384), ("64 KiB", 65_536), ("256 KiB", 262_144)] {
            let source = workload.source(minimumBytes: bytes)
            func configuration(syntax: String, validation: String) -> Benchmark.Configuration {
                .init(metrics: [.wallClock, .mallocCountTotal, .mallocBytesCount],
                    tags: ["bytes": String(source.count), "corpus": workload.rawValue,
                           "profile": "commonmark", "syntax": syntax, "validation": validation],
                    maxDuration: .seconds(5))
            }
            for collect in [false, true] {
                let syntax = collect ? "on" : "off"
                Benchmark("GMSetzer \(workload.rawValue) parse syntax-\(syntax) \(size)",
                          configuration: configuration(syntax: syntax, validation: "swift-repair")) { benchmark in
                    for _ in benchmark.scaledIterations {
                        let parser = try MarkdownParser(collectSyntaxDetails: collect).validated()
                        blackHole(parser.parse(bytes: source))
                    }
                }
            }
            for validate in [false, true] {
                let validation = validate ? "on" : "off"
                Benchmark("cmark-gfm (C) \(workload.rawValue) parse validation-\(validation) \(size)",
                          configuration: configuration(syntax: "off", validation: validation)) { benchmark in
                    for _ in benchmark.scaledIterations {
                        let options = CMARK_OPT_SOURCEPOS | (validate ? CMARK_OPT_VALIDATE_UTF8 : 0)
                        let parser = cmark_parser_new(options)
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
