// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GameCalendarNative",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    targets: [
        .executableTarget(
            name: "GameCalendarNative",
            path: "Sources/GameCalendarNative"
        ),
    ]
)
