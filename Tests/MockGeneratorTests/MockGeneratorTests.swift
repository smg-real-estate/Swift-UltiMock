import Foundation
import PathKit
import Testing
@testable import mock

struct MockGeneratorTests {
    let pluginTestsPath = Path(#filePath).parent().parent().parent() + "PluginTests/"

    @Test func mockGeneration_MockTests() throws {
        let sdkPath = try #require(getRootSDKPath())
        let path = pluginTestsPath + "Tests/MockTests/mock.json"
        let outputPath = FileManager.default.temporaryDirectory.appending(path: "MockTests.generated.swift")

        setenv("SDKROOT", sdkPath, 1)

        var mockCommand = try MockCommand.parseAsRoot([
            path.string,
            "--sources",
            (pluginTestsPath + "Tests/MockTests").string,
            (pluginTestsPath + "Tests/TestableMockables").string,
            "--output", outputPath.path,
        ])

        try mockCommand.run()

        let generatedContent = try String(contentsOf: outputPath)

        let expectedMocks: Set = [
            "InternalMockableMock",
            "InternalSubclassOfAPublicClassMock",
            "ObjCMockableMock",
            "RefinedGenericProtocolMock",
            "SourceryIssue1Mock",
            "TestableMockableMock",
        ]

        for mock in expectedMocks {
            #expect(generatedContent.contains(mock))
        }
    }

    @Test func mockGeneration_TestMocks() throws {
        let sdkPath = try #require(getRootSDKPath())
        let path = pluginTestsPath + "Tests/TestMocks/mock.json"
        let outputPath = FileManager.default.temporaryDirectory.appending(path: "TestMocks.generated.swift")

        setenv("SDKROOT", sdkPath, 1)
        setenv("LLVM_TARGET_TRIPLE_VENDOR", "apple", 1)
        setenv("LLVM_TARGET_TRIPLE_OS_VERSION", "macos13.0", 1)
        setenv("LLVM_TARGET_TRIPLE_SUFFIX", "", 1)
//        setenv("SOURCEKIT_LOGGING", "3", 1)

        var mockCommand = try MockCommand.parseAsRoot([
            path.string,
            "--sources",
            (pluginTestsPath + "Tests/TestMocks").string,
            (pluginTestsPath + "TestPackage/Sources").string,
            "--output", outputPath.path,
        ])

        try mockCommand.run()

        let expectedMocks: Set = [
            "TestMockableMock",
            "GenericTestMockableMock",
            "TestMockableClassMock",
            "Test3rdPartyProtocolMock",
            "CLLocationManagerMock"
        ]

        let generatedContent = try String(contentsOf: outputPath)

        for mock in expectedMocks {
            #expect(generatedContent.contains(mock))
        }
    }
}

func getRootSDKPath() -> String? {
    let process = Process()
    process.launchPath = "/usr/bin/xcrun"
    process.arguments = ["--sdk", "macosx", "--show-sdk-path"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    if let sdkPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
        return sdkPath
    }

    return nil
}
