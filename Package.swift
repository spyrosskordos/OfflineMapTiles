// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OfflineMapTiles",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "OfflineMapTiles",
            targets: ["OfflineMapTiles"]),
    ],
    dependencies: [
        // Add dependencies here if needed in the future
    ],
    targets: [
        .target(
            name: "OfflineMapTiles",
            dependencies: [],
            path: "Sources/OfflineMapTiles",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "OfflineMapTilesTests",
            dependencies: ["OfflineMapTiles"],
            path: "Tests/OfflineMapTilesTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
