// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrainingKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TrainingKit", targets: ["TrainingKit"])
    ],
    targets: [
        .target(name: "TrainingKit"),
        .testTarget(
            name: "TrainingKitTests",
            dependencies: ["TrainingKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
