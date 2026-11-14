// swift-tools-version: 6.0
import PackageDescription

// Shared between Hearthside Solitaire and Sweet Arrows. No game-specific code in here.
// Contains the protocols, the pure policy logic (ad frequency, entitlements, config,
// saves) and the StoreKit 2 implementation. Adapters for third-party SDKs (Google Mobile
// Ads + UMP, Firebase) live in the app target (Hearthside/Services/SDKAdapters.swift),
// so this package has no external dependencies and builds and tests anywhere.
let package = Package(
    name: "GameServices",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameServices", targets: ["GameServices"])
    ],
    targets: [
        .target(name: "GameServices"),
        .testTarget(name: "GameServicesTests", dependencies: ["GameServices"])
    ]
)
