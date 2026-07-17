// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StudyTracker",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "StudyTracker"
        ),
        .testTarget(
            name: "StudyTrackerTests",
            dependencies: ["StudyTracker"]
        )
    ]
)
