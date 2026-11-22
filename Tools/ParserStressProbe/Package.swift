// swift-tools-version: 6.2
import PackageDescription

let package = Package(name: "ParserStressProbe", platforms: [.macOS(.v15)],
    dependencies: [.package(name: "GMSetzer", path: "../..")],
    targets: [.executableTarget(name: "ParserStressProbe", dependencies: [
        .product(name: "GMSetzer", package: "GMSetzer"),
    ])])
