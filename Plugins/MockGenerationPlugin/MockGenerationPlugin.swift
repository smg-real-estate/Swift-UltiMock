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
            .map(\.url)
            .first(where: { $0.lastPathComponent == "mock.json" }) else {
            throw SimpleError("Missing configuration file in \(target.directoryURL)")
        }

        let configuration = try JSONDecoder().decode(
            Configuration.self,
            from: Data(contentsOf: configurationPath)
        )

        let inputFiles = [
            target.dependencySources(matching: configuration.packageDependencies ?? []),
            configuration.sources.map {
                target.directoryURL.appending(path: $0)
            }
        ]
            .flatMap(\.self)

        let imports = [
            configuration.imports,
            configuration.packageDependencies
        ]
            .compactMap(\.self)
            .flatMap(\.self)

        let output = context.pluginWorkDirectoryURL.appending(path: "Mock.generated.swift")

        var options = [
            "output": [output.path],
            "sources": inputFiles.map(\.path)
        ]

        if !imports.isEmpty {
            options["imports"] = imports
        }

        options["testable-imports"] = configuration.testableImports

        let mock = try context.tool(named: "mock").url

        let arguments = [configurationPath.path]
            + options.map { ["--\($0)"] + $1 }
            .flatMap(\.self)

        return [
            .buildCommand(
                displayName: "Generate mocks",
                executable: mock,
                arguments: arguments,
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

    var errorDescription: String? {
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
    let testableImports: [String]?
}

extension PackagePlugin.Target {
    func dependencySources(matching dependencies: [String]) -> [URL] {
        guard !dependencies.isEmpty else {
            return []
        }

        return recursiveTargetDependencies
            .filter { dependencies.contains($0.name) }
            .map(\.directoryURL)
    }
}
