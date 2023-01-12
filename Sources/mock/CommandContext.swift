import PathKit
import SourceKittenFramework
import SourceryFramework
import SourceryRuntime
import XFoundation

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
                Path($0, relativeTo: root)
            }

        let outputPath = try (output ?? configuration.output).map {
            Path($0, relativeTo: root)
        }
        .unwrap("The output path is missing. Use `output` argument or configuration field.")

        self.outputPath = outputPath.isDirectory ? outputPath + mockFilename : outputPath
    }

    func parse() throws -> FileParserResult {
        [
            try parseSources(),
            try parseSDKModules()
        ]
            .flatMap { $0 }
            .reduce(FileParserResult(path: nil, module: nil, types: [], functions: [], typealiases: [])) { result, next in
                result.typealiases += next.typealiases
                result.types += next.types
                result.functions += next.functions
                return result
            }
    }
}

private extension CommandContext {
    func parseSources() throws -> [FileParserResult] {
        let sourceFiles = try sources
            .flatMap { path in
                path.isDirectory ? try path.recursiveChildren() : [path]
            }
            .filter { path in
                !path.isDirectory && path.extension == "swift" && !path.string.hasSuffix("generated.swift")
            }

        return try sourceFiles
            .map { filePath -> FileParserResult in
                let content = try filePath.read(.utf8)
                let parser = try makeParser(for: content)
                return try parser.parse()
            }
    }

    func parseSDKModules() throws -> [FileParserResult] {
        // Required for running in sandbox environment
        setenv("IN_PROCESS_SOURCEKIT", "YES", 1)
        //        setenv("SOURCEKIT_LOGGING", "3", 1)

        let moduleCache = FileManager.default.temporaryDirectory
            .appendingPathComponent("clang/ModuleCache")
            .path

        let developerDirectory = try shell("xcode-select -p")
            .trimmingTrailingCharacters(in: .newlines)

        return try (configuration.sdkModules ?? [:])
            .flatMap { platform, modules in
                let sdkPath = Path("\(developerDirectory)/Platforms/\(platform).platform/Developer/SDKs/\(platform).sdk")

                let sdkSettings = try JSONDecoder().decode(SDKSettings.self, from: try (sdkPath + "SDKSettings.json").read())

                return try modules.map { module in
                    let request = SourceKittenFramework.Request.customRequest(request: [
                        "key.request": UID("source.request.editor.open.interface"),
                        "key.name": UUID().uuidString,
                        "key.compilerargs": [
                            "-target",
                            try targetTriple(sdkSettings.defaultDeploymentTarget),
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

                    let source: String = try cast(toNSDictionary(try request.send())["key.sourcetext"])
                    return try makeParser(for: source).parse()
                }
            }
    }

    func targetTriple(_ deploymentTarget: String) throws -> String {
        "\(try systemArchitectureIdentifier())-apple-ios\(deploymentTarget)-simulator"
    }
}

func systemArchitectureIdentifier() throws -> String {
    var systemInfo = utsname()

    guard uname(&systemInfo) == EXIT_SUCCESS else {
        throw "Unable to detect target architecture"
    }

    let data = Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN))

    let identifier = try String(bytes: data, encoding: .ascii)
        .unwrap("Unknown architecture")

    return identifier.trimmingCharacters(in: .controlCharacters)
}

struct SDKSettings: Decodable {
    let defaultDeploymentTarget: String

    enum CodingKeys: String, CodingKey {
        case defaultDeploymentTarget = "DefaultDeploymentTarget"
    }
}
