// swift-tools-version: 6.2
import PackageDescription

// Bounded, development-only stage probe. No dependencies reach the library.
let package = Package(
    name: "ProgressiveHTMLProbe",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../..")],
    targets: [.executableTarget(name: "ProgressiveHTMLProbe", dependencies: [
        .product(name: "GMSetzer", package: "GMSetzer"),
    ])]
)
