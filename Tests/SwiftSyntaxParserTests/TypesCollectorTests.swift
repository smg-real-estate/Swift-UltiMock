import SwiftParser
import SwiftSyntax
import Testing
@testable import UltiMockSwiftSyntaxParser

@Suite struct TypesCollectorTests {
    private let collector = TypesCollector()

    @Test
    func collectsProtocolAndExtensionsIndividually() throws {
        let source = Parser.parse(source:
            """
            /// Greeter API description
            protocol Greeter {
            }

            // Extension adds defaults
            extension Greeter {
                func greet() {}
            }
            """
        )

        let types = collector.collect(from: source)
        #expect(types.count == 2)

        guard
            let protocolType = types.first(where: { $0.kind == .protocol }),
            let extensionType = types.first(where: { $0.isExtension })
        else {
            Issue.record("Missing protocol or extension entry")
            return
        }

        #expect(protocolType.name == "Greeter")
        #expect(protocolType.isExtension == false)
        #expect(protocolType.comment?.contains("Greeter API description") == true)

        #expect(extensionType.name == "Greeter")
        #expect(extensionType.isExtension == true)
        #expect(extensionType.comment?.contains("Extension adds defaults") == true)
    }

    @Test
    func preservesMultipleExtensions() throws {
        let source = Parser.parse(source:
            """
            protocol Worker {}

            extension Worker {
            }

            extension Worker: Sendable {}
            """
        )

        let types = collector.collect(from: source)
        #expect(types.filter { $0.isExtension }.count == 2)
        let inheritance = types
            .filter { $0.isExtension }
            .map { $0.inheritedTypes }

        #expect(inheritance.contains([]))
        #expect(inheritance.contains(["Sendable"]))
    }
}
