// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HearthsideCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HearthsideCore", targets: ["HearthsideCore"])
    ],
    targets: [
        .target(name: "HearthsideCore"),
        .testTarget(name: "HearthsideCoreTests", dependencies: ["HearthsideCore"])
    ]
)
