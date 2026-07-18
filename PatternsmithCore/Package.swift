// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PatternsmithCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PatternsmithCore", targets: ["PatternsmithCore"]),
    ],
    targets: [
        .target(name: "PatternsmithCore"),
        .testTarget(
            name: "PatternsmithCoreTests",
            dependencies: ["PatternsmithCore"]
        ),
    ]
)
