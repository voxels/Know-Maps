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
    dependencies: [
        .package(url: "https://github.com/kean/Nuke", exact: "12.8.0"),
        .package(url: "https://github.com/segmentio/analytics-swift", exact: "1.6.2"),
        .package(url: "https://github.com/supabase/supabase-swift", exact: "2.33.1"),
    ],
    targets: [
        .target(
            name: "knowmaps",
            dependencies: [
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "Segment", package: "analytics-swift"),
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "Know-Maps/knowmaps"
        ),
        .testTarget(
            name: "knowmapsTests",
            dependencies: ["knowmaps"],
            path: "Know-Maps/knowmapsTests"
        ),
    ]
)
