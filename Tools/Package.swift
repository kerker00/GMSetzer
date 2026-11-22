// swift-tools-version: 6.2
import PackageDescription

// Development tools for GMSetzer, kept apart so that their dependencies
// never reach users of the library:
//
// - Benchmarks (package-benchmark): GMSetzer against cmark-gfm in C (the
//   speed reference) and against swift-markdown (cmark-gfm plus building a
//   Swift tree, closer to what an app pays) on the same documents.
//
// Run from this directory: `swift package benchmark`.
let package = Package(
    name: "GMSetzerTools",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.27.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.9.0"),
        // cmark-gfm in C, the reference for parse speed.
        .package(url: "https://github.com/swiftlang/swift-cmark.git", from: "0.9.0"),
    ],
    targets: [
        // Optional cross-language comparison driver; third-party source builds
        // are kept outside SwiftPM and outside the library dependency graph.
        .executableTarget(name: "ParserComparisonProbe", dependencies: [
            "BenchmarkCorpus", .product(name: "GMSetzer", package: "GMSetzer"),
            .product(name: "cmark-gfm", package: "swift-cmark"),
        ]),
        // Deterministic Markdown documents of a given size.
        .target(name: "BenchmarkCorpus", dependencies: [.product(name: "GMSetzer", package: "GMSetzer")]),
        .testTarget(name: "BenchmarkCorpusTests", dependencies: [
            "BenchmarkCorpus", .product(name: "GMSetzer", package: "GMSetzer"),
        ]),
        .testTarget(
            name: "ContainerReferenceTests",
            dependencies: [
                "BenchmarkCorpus",
                .product(name: "GMSetzer", package: "GMSetzer"),
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ]
        ),
        .executableTarget(
            name: "UTF8Benchmarks",
            dependencies: [
                "BenchmarkCorpus",
                .product(name: "GMSetzer", package: "GMSetzer"),
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/UTF8Benchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "package-benchmark")]
        ),
        .executableTarget(
            name: "HardeningBenchmarks",
            dependencies: [
                "BenchmarkCorpus",
                .product(name: "GMSetzer", package: "GMSetzer"),
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/HardeningBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "package-benchmark")]
        ),
        .executableTarget(
            name: "ParserBenchmarks",
            dependencies: [
                "BenchmarkCorpus",
                .product(name: "GMSetzer", package: "GMSetzer"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/ParserBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "package-benchmark")]
        ),
    ]
)
