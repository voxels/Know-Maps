// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "knowmaps",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "knowmaps", targets: ["knowmaps"]),
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
            path: "Know-Maps/Know Maps Prod",
            exclude: [
                "Info.plist",
                "Know Maps ProdDebug.entitlements",
                "Know_Maps_Prod.entitlements",
                "Preview Content",
                "Model/Documentation",
                "Model/ML/FoursquareClassifierTrainingData.csv",
                "Model/ML/QueryClassifierTrainingData.json",
                "Model/ML/WordTaggingClassifierTrainingData.json",
                "Model/ML/WordTaggingClassifierTrainingData_FULLSET.json",
                "Model/ML/WordTaggingClassifierTrainingData_TestData.json",
                "Model/ML/WordTaggingClassifierTrainingData_TestData",
                "Model/Controllers/inspect_mlpackage.py",
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Model/Controllers/integrated_category_taxonomy.json"),
                .process("Model/Models/vocab.txt"),
            ]
        ),
        .testTarget(
            name: "knowmapsTests",
            dependencies: ["knowmaps"],
            path: "Know-Maps/knowmapsTests"
        ),
    ]
)

