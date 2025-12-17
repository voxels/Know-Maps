// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KnowMaps",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "KnowMaps",
            targets: ["KnowMaps"]
        )
    ],
    dependencies: [
        .package(path: "../../../../DiverKit"),
        // External dependencies from the original project
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/segmentio/analytics-swift.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "KnowMaps",
            dependencies: [
                "DiverKit",
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Segment", package: "analytics-swift")
            ],
            path: "Know Maps Prod",
            exclude: [
                "Assets.xcassets",
                "Preview Content",
                "Info.plist",
                "Know_Maps_Prod.entitlements",
                "Know Maps ProdDebug.entitlements"
            ],
            resources: [
                .process("Model/ML")
            ]
        ),
        .testTarget(
            name: "KnowMapsTests",
            dependencies: ["KnowMaps"],
            path: "Know MapsTests"
        )
    ]
)
