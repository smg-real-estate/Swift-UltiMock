// swift-tools-version:6.2
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
        .package(url: "https://github.com/jpsim/SourceKitten", from: "0.32.0"),
        .package(url: "https://github.com/freddi-kit/ArtifactBundleGen.git", from: "0.0.6"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/kylef/PathKit.git", exact: "1.0.1")
    ],
    targets: [
        .target(
            name: "UltiMock",
            dependencies: ["XCTestExtensions"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(name: "XCTestExtensions"),
        .target(
            name: "SyntaxParser",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "mock",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "PathKit", package: "PathKit"),
                "SyntaxParser"
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .plugin(
            name: "MockGenerationPlugin",
            capability: .buildTool(),
            dependencies: ["mock"]
        ),
        .testTarget(
            name: "SyntaxParserTests",
            dependencies: [
                "SyntaxParser",
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "MockGeneratorTests",
            dependencies: [
                "mock"
            ]
        )
    ]
)
