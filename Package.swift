// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "knowmaps",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "knowmaps",
            targets: ["knowmaps"]
        ),
    ],
    targets: [
        .target(
            name: "knowmaps",
            path: "Know-Maps/knowmaps"
        ),
        .testTarget(
            name: "knowmapsTests",
            dependencies: ["knowmaps"],
            path: "Know-Maps/knowmapsTests"
        ),
    ]
)

