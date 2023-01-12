import Foundation
import PackagePlugin

@main
struct MockGenerationPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PackagePlugin.PluginContext,
        target: PackagePlugin.Target
    ) async throws -> [PackagePlugin.Command] {
        guard let target = target as? SourceModuleTarget else {
            return []
        }

        guard let configurationPath = target.sourceFiles
            .map(\.path)
            .first(where: { $0.lastComponent == "mock.json" }) else {
            throw SimpleError("Missing configuration file in \(target.directory)")
        }

        let configuration = try JSONDecoder().decode(
            Configuration.self,
            from: Data(contentsOf: URL(fileURLWithPath: configurationPath.string))
        )

        let inputFiles = [
            configuration.sources.map {
                target.directory.appending(subpath: $0)
            },
            target.dependencySources(matching: configuration.packageDependencies ?? [])
        ]
            .flatMap { $0 }

        let imports = [
            configuration.imports,
            configuration.packageDependencies
        ]
            .compactMap { $0 }
            .flatMap { $0 }

        let output = context.pluginWorkDirectory.appending(["Mock.generated.swift"])

        let mock = try context.tool(named: "mock").path

        return [
            .buildCommand(
                displayName: "Generate mocks",
                executable: mock,
                arguments: [configurationPath.string, "--sources"]
                    + inputFiles.map(\.string)
                    + ["--imports"] + imports
                    + ["--output", output.string],
                inputFiles: inputFiles + [configurationPath],
                outputFiles: [output]
            )
        ]
    }
}

struct SimpleError: LocalizedError, CustomStringConvertible {
    let localizedDescription: String

    init(_ localizedDescription: String) {
        self.localizedDescription = localizedDescription
    }

    public var errorDescription: String? {
        localizedDescription
    }

    var description: String {
        "Error: \(localizedDescription)"
    }
}

struct Configuration: Decodable {
    let sources: [String]
    let packageDependencies: [String]?
    let imports: [String]?
}

extension PackagePlugin.Target {
    func dependencySources(matching dependencies: [String]) -> [Path] {
        guard !dependencies.isEmpty else {
            return []
        }

        return recursiveTargetDependencies
            .filter { dependencies.contains($0.name) }
            .map(\.directory)
    }
}
