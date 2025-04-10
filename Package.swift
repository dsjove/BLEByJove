// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "BLEByJove",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        .library(
            name: "BLEByJove",
            targets: ["BLEByJove"]),
    ],
    dependencies: [
        .package(
			url: "https://github.com/apple/swift-collections.git",
			.upToNextMinor(from: "1.0.4") // or `.upToNextMajor
		)
    ],
    targets: [
        .target(
            name: "BLEByJove",
            dependencies: [
				.product(name: "Collections", package: "swift-collections")
			]),
        .testTarget(
            name: "BLEByJoveTests",
            dependencies: ["BLEByJove"]),
    ]
)
