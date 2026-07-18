// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PatternautCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PatternautCore", targets: ["PatternautCore"]),
    ],
    targets: [
        .target(name: "PatternautCore"),
        .testTarget(
            name: "PatternautCoreTests",
            dependencies: ["PatternautCore"]
        ),
    ]
)
