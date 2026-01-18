// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BLEByJove",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(
            name: "BLEByJove",
            targets: ["BLEByJove"]),
    ],
    dependencies: [
        .package(path: "../SBJKit"),
        .package(
			url: "https://github.com/apple/swift-collections.git",
			.upToNextMinor(from: "1.0.4") // or `.upToNextMajor
		)
    ],
    targets: [
        .target(
            name: "BLEByJove",
            dependencies: [
				"SBJKit",
				.product(name: "Collections", package: "swift-collections")
			]),
        .testTarget(
            name: "BLEByJoveTests",
            dependencies: ["BLEByJove"]),
    ]
)
