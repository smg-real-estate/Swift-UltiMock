// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TestPackage",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(
            name: "TestPackage",
            targets: ["TestPackage"]
        )
    ],
    targets: [
        .target(
            name: "TestPackage"
        )
    ]
)
