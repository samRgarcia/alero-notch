// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Alero",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Alero", path: "Sources/Alero")
    ]
)
