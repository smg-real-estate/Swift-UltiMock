// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PluginTests",
    platforms: [.iOS(.v16), .macOS(.v13)],
    dependencies: [
        .package(name: "UltiMock", path: "../"),
        .package(path: "TestPackage")
    ],
    targets: [
        // We generate the mocks in a separate target to ensure the mocks are defined as `public`
        .target(
            name: "TestMocks",
            dependencies: [
                "UltiMock",
                "TestPackage"
            ],
            path: "Tests/TestMocks",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-warnings-as-errors"])
            ],
            plugins: [
                .plugin(name: "MockGenerationPlugin", package: "UltiMock")
            ]
        ),
        .target(
            name: "TestableMockables",
            path: "Tests/TestableMockables"
        ),
        .testTarget(
            name: "MockTests",
            dependencies: [
                "UltiMock",
                "TestMocks",
                "TestableMockables"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-warnings-as-errors"])
            ],
            plugins: [
                .plugin(name: "MockGenerationPlugin", package: "UltiMock")
            ]
        )
    ]
)
