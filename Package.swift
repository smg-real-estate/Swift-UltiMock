// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
    name: "UltiMock",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(
            name: "UltiMock",
            targets: ["UltiMock"]
        ),
        .executable(
            name: "mock",
            targets: ["mock"]
        ),
        .plugin(
            name: "MockGenerationPlugin",
            targets: ["MockGenerationPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.1"),
        .package(name: "Sourcery", path: "Submodules/Sourcery"),
        .package(url: "https://github.com/jpsim/SourceKitten", from: "0.32.0"),
        .package(url: "https://github.com/freddi-kit/ArtifactBundleGen.git", from: "0.0.6")
    ],
    targets: [
        .target(
            name: "UltiMock",
            dependencies: ["XCTestExtensions"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(name: "XCTestExtensions"),
        .executableTarget(
            name: "mock",
            dependencies: [
                .product(name: "SourceryFramework", package: "Sourcery"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SourceKittenFramework", package: "SourceKitten")
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .plugin(
            name: "MockGenerationPlugin",
            capability: .buildTool(),
            dependencies: ["mock"]
        )
    ]
)
