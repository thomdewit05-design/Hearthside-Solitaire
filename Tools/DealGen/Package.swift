// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DealGen",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "dealgen", targets: ["dealgen"])
    ],
    dependencies: [
        .package(path: "../../Packages/HearthsideCore")
    ],
    targets: [
        .executableTarget(name: "dealgen", dependencies: ["HearthsideCore"])
    ]
)
