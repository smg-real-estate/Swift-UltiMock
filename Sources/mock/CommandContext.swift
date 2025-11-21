import Foundation
import PathKit
import SourceKittenFramework
import SwiftParser
import SwiftSyntax
import SyntaxParser

struct CommandContext {
    let configuration: Configuration
    let configurationPath: Path
    let sources: [Path]
    let outputPath: Path

    init(_ configurationPath: ConfigurationPath, _ sources: [String], _ output: String?) throws {
        let root = configurationPath.resolvedPath.parent()
        self.configurationPath = configurationPath.resolvedPath
        let configurationData = try configurationPath.resolvedPath.read()
        self.configuration = try JSONDecoder().decode(Configuration.self, from: configurationData)
        self.sources = (sources.isEmpty ? configuration.sources : sources)
            .map {
                root + Path($0)
            }

        let outputPath = try (output ?? configuration.output).map {
            root + Path($0)
        }
        .unwrap("The output path is missing. Use `output` argument or configuration field.")

        self.outputPath = outputPath.isDirectory ? outputPath + mockFilename : outputPath
    }

    func parse() throws -> [SyntaxParser.Syntax.TypeInfo] {
        let rawTypes = try [
            parseSources(),
            parseSDKModules()
        ]
            .flatMap(\.self)

        return TypeInfoResolver().resolve(rawTypes)
    }
}

private extension CommandContext {
    func parseSources() throws -> [SyntaxParser.Syntax.TypeInfo] {
        let sourceFiles = try sources
            .flatMap { path in
                path.isDirectory ? try path.recursiveChildren() : [path]
            }
            .filter { path in
                !path.isDirectory && path.extension == "swift" && !path.string.hasSuffix("generated.swift")
            }

        let collector = TypesCollector()

        return try sourceFiles
            .flatMap { filePath -> [SyntaxParser.Syntax.TypeInfo] in
                let content = try filePath.read(.utf8)
                let source = Parser.parse(source: content)
                return collector.collect(from: source)
            }
    }

    func parseSDKModules() throws -> [SyntaxParser.Syntax.TypeInfo] {
        // Required for running in sandbox environment
        setenv("IN_PROCESS_SOURCEKIT", "YES", 1)
        //        setenv("SOURCEKIT_LOGGING", "3", 1)

        let moduleCache = FileManager.default.temporaryDirectory
            .appendingPathComponent("clang/ModuleCache")
            .path

        let sdkPath = try Path(env["SDKROOT"].wrapped)
        let collector = TypesCollector()

        return try (configuration.sdkModules ?? [])
            .flatMap { module -> [SyntaxParser.Syntax.TypeInfo] in
                let request = try SourceKittenFramework.Request.customRequest(request: [
                    "key.request": UID("source.request.editor.open.interface"),
                    "key.name": UUID().uuidString,
                    "key.compilerargs": [
                        "-target",
                        targetTriple(),
                        "-sdk",
                        sdkPath.string,
                        "-I",
                        (sdkPath + "usr/local/include").string,
                        "-F",
                        (sdkPath + "System/Library/PrivateFrameworks").string,
                        // Default module cache directory is not accessible from a plugin sandbox environment
                        "-module-cache-path",
                        moduleCache
                    ],
                    "key.modulename": module,
                    "key.toolchains": [String](), // "com.apple.dt.toolchain.XcodeDefault",
                    "key.synthesizedextensions": 1
                ])

                let response: [String: any SourceKitRepresentable]

                do {
                    response = try request.send()
                } catch {
                    print("Failed to parse SDK module '\(module)': \(error)")
                    return []
                }

                let sourceText: String = try cast(response["key.sourcetext"])
                let source = Parser.parse(source: sourceText)
                return collector.collect(from: source)
            }
    }

    func targetTriple() throws -> String {
        try [
            systemArchitectureIdentifier(),
            "-",
            env["LLVM_TARGET_TRIPLE_VENDOR"],
            "-",
            env["LLVM_TARGET_TRIPLE_OS_VERSION"],
            env["LLVM_TARGET_TRIPLE_SUFFIX"]
        ]
            .compactMap(\.self)
            .joined()
    }
}

func systemArchitectureIdentifier() throws -> String {
    var systemInfo = utsname()

    guard uname(&systemInfo) == EXIT_SUCCESS else {
        throw SimpleError("Unable to detect target architecture")
    }

    let data = Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN))

    let identifier = try String(bytes: data, encoding: .ascii)
        .unwrap("Unknown architecture")

    return identifier.trimmingCharacters(in: .controlCharacters)
}

var env: [String: String] {
    ProcessInfo.processInfo.environment
}
