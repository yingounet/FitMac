// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FitMacCore",
            targets: ["FitMacCore"]
        ),
        .executable(
            name: "fitmac",
            targets: ["FitMacCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "FitMacCore",
            dependencies: [],
            path: "Sources/FitMacCore"
        ),
        .executableTarget(
            name: "FitMacCLI",
            dependencies: [
                "FitMacCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/FitMacCLI"
        ),
        .testTarget(
            name: "FitMacCoreTests",
            dependencies: ["FitMacCore"],
            path: "Tests/FitMacCoreTests"
        ),
    ]
)
