// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "FileStack",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "FileStack", path: "Sources/FileStack"),
    ]
)
