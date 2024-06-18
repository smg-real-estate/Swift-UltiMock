// swift-tools-version:5.7
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
        .package(url: "https://github.com/smg-real-estate/Swift-XFoundation.git", from: "0.1.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.1"),
        .package(url: "https://github.com/krzysztofzablocki/Sourcery", revision: "2.0.2"),
        .package(url: "https://github.com/jpsim/SourceKitten", from: "0.32.0")
    ],
    targets: [
        .target(
            name: "UltiMock",
            dependencies: ["XCTestExtensions"]
        ),
        .target(name: "XCTestExtensions"),
        .executableTarget(
            name: "mock",
            dependencies: [
                .product(name: "SourceryFramework", package: "Sourcery"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "XFoundation-static", package: "Swift-XFoundation")
            ]
        ),
        .plugin(
            name: "MockGenerationPlugin",
            capability: .buildTool(),
            dependencies: ["mock"]
        )
    ]
)
