// swift-tools-version: 6.2
import PackageDescription

// Development tools for GMSetzer, kept apart so that their dependencies
// never reach users of the library:
//
// - Benchmarks (package-benchmark): GMSetzer against cmark-gfm through
//   swift-markdown on the same generated documents.
//
// Run from this directory: `swift package benchmark`.
let package = Package(
    name: "GMSetzerTools",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.27.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.5.0"),
    ],
    targets: [
        // Deterministic Markdown documents of a given size.
        .target(name: "BenchmarkCorpus"),
        .executableTarget(
            name: "ParserBenchmarks",
            dependencies: [
                "BenchmarkCorpus",
                .product(name: "GMSetzer", package: "GMSetzer"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/ParserBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "package-benchmark")]
        ),
    ]
)
