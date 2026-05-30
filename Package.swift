// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TalkBridgeMenubar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "TalkBridgeMenubar",
            path: "Sources/TalkBridgeMenubar"
        ),
        .testTarget(
            name: "TalkBridgeMenubarTests",
            dependencies: ["TalkBridgeMenubar"],
            path: "Tests/TalkBridgeMenubarTests"
        )
    ]
)
