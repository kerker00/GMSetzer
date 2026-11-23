// swift-tools-version: 6.2
import PackageDescription

// The library has no runtime dependencies: the core uses the Swift standard
// library only, so it builds wherever Swift runs, including Linux.
// Benchmarks and reference comparisons live in the separate package in
// `Tools/`, so their dependencies never reach users of GMSetzer.

let strict: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "GMSetzer",
    platforms: [
        // Declared deployment minimums for the 1.0 source API.
        .macOS(.v15), .iOS(.v18), .visionOS(.v2),
    ],
    products: [
        .library(name: "GMSetzer", targets: ["GMSetzer"]),
        .library(name: "SetzerSyntax", targets: ["SetzerSyntax"]),
        .library(name: "SetzerParser", targets: ["SetzerParser"]),
        .library(name: "SetzerExtensions", targets: ["SetzerExtensions"]),
        .library(name: "SetzerHTML", targets: ["SetzerHTML"]),
        .library(name: "SetzerAnalysis", targets: ["SetzerAnalysis"]),
    ],
    targets: [
        // Syntax tree, source ranges, position conversion, outline queries.
        .target(name: "SetzerSyntax", swiftSettings: strict),
        // Block and inline parser, extension API, profiles.
        .target(name: "SetzerParser", dependencies: ["SetzerSyntax"], swiftSettings: strict),
        // GFM, footnotes, front matter, math, alerts and callouts.
        .target(name: "SetzerExtensions", dependencies: ["SetzerParser", "SetzerSyntax"], swiftSettings: strict),
        // HTML renderer with block anchors and safe defaults.
        .target(name: "SetzerHTML", dependencies: ["SetzerSyntax"], swiftSettings: strict),
        .target(name: "SetzerAnalysis", dependencies: ["SetzerSyntax"], swiftSettings: strict),
        // Convenience module re-exporting the above.
        .target(name: "GMSetzer", dependencies: ["SetzerSyntax", "SetzerParser", "SetzerExtensions", "SetzerHTML", "SetzerAnalysis"], swiftSettings: strict),

        .testTarget(name: "SetzerParserTests", dependencies: ["GMSetzer"], swiftSettings: strict),
        // Runs every example of the CommonMark and GFM specifications.
        .testTarget(
            name: "SetzerSpecTests",
            dependencies: ["GMSetzer"],
            resources: [.copy("Resources")],
            swiftSettings: strict
        ),
    ]
)
