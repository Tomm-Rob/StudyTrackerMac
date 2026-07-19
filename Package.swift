// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StudyTracker",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "StudyTracker",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/StudyTracker/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "StudyTrackerTests",
            dependencies: ["StudyTracker"]
        )
    ]
)
