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
                "Model/ML/LocalMapsArtRegressor.mlproj",
                "Model/ML/LocalMapsQueryClassifier.mlproj",
                "Model/ML/LocalMapsQueryTagger.mlproj",
                "Model/ML/FoursquareClassifierTrainingData.csv",
                "Model/ML/QueryClassifierTrainingData.json",
                "Model/ML/WordTaggingClassifierTrainingData.json",
                "Model/ML/WordTaggingClassifierTrainingData_FULLSET.json",
                "Model/ML/WordTaggingClassifierTrainingData_TestData.json",
                "Model/ML/WordTaggingClassifierTrainingData_TestData",
                "Model/Controllers/inspect_mlpackage.py",
                "Model/Controllers/LocalMapsQueryTagger.mlpackage/Manifest.json",
                "Model/Controllers/LocalMapsQueryTagger.mlpackage/Data/com.apple.CoreML/Metadata.json",
                "Model/Controllers/LocalMapsQueryTagger.mlpackage/Data/com.apple.CoreML/FeatureDescriptions.json",
                "Model/Controllers/MiniLM-L12-Embedding.mlpackage/Manifest.json",
                "Model/Controllers/MiniLM-L12-Embedding.mlpackage/Data/com.apple.CoreML/Metadata.json",
                "Model/Controllers/MiniLM-L12-Embedding.mlpackage/Data/com.apple.CoreML/FeatureDescriptions.json",
                "Model/Controllers/MiniLM-L12-Embedding.mlpackage/Data/com.apple.CoreML/weights/weight.bin",
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Model/Audio"),
                .process("Model/Controllers/LocalMapsQueryTagger.mlpackage/Data/com.apple.CoreML/LocalMapsQueryTagger.mlmodel"),
                .process("Model/Controllers/MiniLM-L12-Embedding.mlpackage/Data/com.apple.CoreML/model.mlmodel"),
                .process("Model/Controllers/integrated_category_taxonomy.json"),
                .process("Model/ML/FoursquareSectionClassifier.mlmodel"),
                .process("Model/Controllers/LocalMapsQueryClassifier.mlmodel"),
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
