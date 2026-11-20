// swift-tools-version: 6.2
import PackageDescription

// Development-only executable for SDKs without the Swift Testing module.
// No dependency is added to the library package.
let package = Package(
    name: "PortabilityProbe",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../..")],
    targets: [.executableTarget(name: "PortabilityProbe", dependencies: [
        .product(name: "GMSetzer", package: "GMSetzer"),
    ])]
)
