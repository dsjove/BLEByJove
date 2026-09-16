// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "BLEByJove",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "BLEByJove",
            targets: ["BLEByJove"]),
    ],
    dependencies: [
        .package(path: "../SBJFoundation"),
        .package(
            url: "https://github.com/apple/swift-collections.git",
            .upToNextMinor(from: "1.0.4")
        )
    ],
    targets: [
        .target(
            name: "BLEByJove",
            dependencies: [
                "SBJFoundation",
                .product(name: "Collections", package: "swift-collections")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]),
        .testTarget(
            name: "BLEByJoveTests",
            dependencies: ["BLEByJove"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]),
    ]
)
