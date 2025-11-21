import ArgumentParser
import Foundation
import SyntaxParser

let configFilename = "mock.json"
let mockFilename = "Mock.generated.swift"

@main
struct MockCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mock",
        abstract: "Mock generation tool",
        discussion: "Generates mocks using Sourcery tool."
    )

    @Argument(help: "Path to the configuration file or a directory containing `\(configFilename)` file.")
    var configurationPath: ConfigurationPath

    @Option(parsing: .upToNextOption, help: "A list of source locations.")
    var sources: [String] = []

    @Option(parsing: .upToNextOption, help: "A list of additional imports for the generated mock.")
    var imports: [String] = []

    @Option(parsing: .upToNextOption, help: "A list of additional @testable imports for the generated mock.")
    var testableImports: [String] = []

    @Option(help: "Path to the output file. If the path is directory the default `Mock.generated.swift` filename will be used.")
    var output: String?

    func run() throws {
        let start = Date()
        let context = try CommandContext(configurationPath, sources, output)

        let types = try context.parse()

        let mockSource = MockTemplate(
            types: types,
            imports: imports.isEmpty ? context.configuration.imports ?? [] : imports,
            testableImports: testableImports
        )
        .render()

        try context.outputPath.write(mockSource)
        print("Generated mock at '\(context.outputPath)'\n in \(-start.timeIntervalSinceNow)s.")
    }
}
