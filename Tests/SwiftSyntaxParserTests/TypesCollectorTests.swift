import SwiftParser
import SwiftSyntax
import Testing
@testable import UltiMockSwiftSyntaxParser

@Suite struct TypesCollectorTests {
    let collector = TypesCollector()

    @Test
    func `collect returns protocol and extension separately with their comments`() throws {
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

        let protocolType = try #require(types.first(where: { $0.kind == .protocol }))
        #expect(protocolType == Syntax.TypeInfo(
            kind: .protocol,
            name: "Greeter",
            localName: "Greeter",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: false,
            comment: "/// Greeter API description\n"
        ))

        let extensionType = try #require(types.first(where: { $0.isExtension }))
        #expect(extensionType == Syntax.TypeInfo(
            kind: .extension,
            name: "Greeter",
            localName: "Greeter",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: true,
            comment: "\n\n// Extension adds defaults\n"
        ))
    }

    @Test
    func `collect returns multiple extensions with their inherited types`() {
        let source = Parser.parse(source:
            """
            protocol Worker {}

            extension Worker {
            }

            extension Worker: Sendable {}
            """
        )

        let types = collector.collect(from: source)
        let extensions = types.filter(\.isExtension)

        #expect(extensions == [
            Syntax.TypeInfo(
                kind: .extension,
                name: "Worker",
                localName: "Worker",
                accessLevel: .internal,
                inheritedTypes: [],
                isExtension: true,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .extension,
                name: "Worker",
                localName: "Worker",
                accessLevel: .internal,
                inheritedTypes: ["Sendable"],
                isExtension: true,
                comment: nil
            )
        ])
    }

    @Test
    func `collect returns struct with modifiers and inherited types`() throws {
        let source = Parser.parse(source:
            """
            /// A user model
            public struct User: Codable, Equatable {
                let name: String
            }
            """
        )

        let types = collector.collect(from: source)
        let structType = try #require(types.first)
        #expect(structType == Syntax.TypeInfo(
            kind: .struct,
            name: "User",
            localName: "User",
            accessLevel: .public,
            inheritedTypes: ["Codable", "Equatable"],
            isExtension: false,
            comment: "/// A user model\n"
        ))
    }

    @Test
    func `collect returns class with modifiers and inherited types`() throws {
        let source = Parser.parse(source:
            """
            /// Base view controller
            open class BaseViewController: UIViewController, Loggable {
            }
            """
        )

        let types = collector.collect(from: source)
        let classType = try #require(types.first)
        #expect(classType == Syntax.TypeInfo(
            kind: .class,
            name: "BaseViewController",
            localName: "BaseViewController",
            accessLevel: .open,
            inheritedTypes: ["UIViewController", "Loggable"],
            isExtension: false,
            comment: "/// Base view controller\n"
        ))
    }

    @Test
    func `collect returns enum with modifiers and inherited types`() throws {
        let source = Parser.parse(source:
            """
            /// Network error types
            internal enum NetworkError: Error, Sendable {
                case timeout
            }
            """
        )

        let types = collector.collect(from: source)
        let enumType = try #require(types.first)
        #expect(enumType == Syntax.TypeInfo(
            kind: .enum,
            name: "NetworkError",
            localName: "NetworkError",
            accessLevel: .internal,
            inheritedTypes: ["Error", "Sendable"],
            isExtension: false,
            comment: "/// Network error types\n"
        ))
    }

    @Test
    func `collect returns public access level`() throws {
        let source = Parser.parse(source: "public struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .public)
    }

    @Test
    func `collect returns private access level`() throws {
        let source = Parser.parse(source: "private struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .private)
    }

    @Test
    func `collect returns fileprivate access level`() throws {
        let source = Parser.parse(source: "fileprivate struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .fileprivate)
    }

    @Test
    func `collect returns open access level`() throws {
        let source = Parser.parse(source: "open class Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .open)
    }

    @Test
    func `collect returns package access level`() throws {
        let source = Parser.parse(source: "package struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .package)
    }

    @Test
    func `collect returns internal access level when no modifier specified`() throws {
        let source = Parser.parse(source: "struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .internal)
    }

    @Test
    func `collect extracts localName from qualified type names`() {
        let source = Parser.parse(source:
            """
            extension Swift.Array {
            }

            extension Foundation.URL: Sendable {
            }
            """
        )

        let types = collector.collect(from: source)
        #expect(types == [
            Syntax.TypeInfo(
                kind: .extension,
                name: "Swift.Array",
                localName: "Array",
                accessLevel: .internal,
                inheritedTypes: [],
                isExtension: true,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .extension,
                name: "Foundation.URL",
                localName: "URL",
                accessLevel: .internal,
                inheritedTypes: ["Sendable"],
                isExtension: true,
                comment: nil
            )
        ])
    }

    @Test
    func `collect extracts line comments preserving newlines`() throws {
        let source = Parser.parse(source:
            """
            // First line
            // Second line

            // Third line after blank
            protocol Example {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)

        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "Example",
            localName: "Example",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: false,
            comment: "// First line\n// Second line\n\n// Third line after blank\n"
        ))
    }

    @Test
    func `collect extracts block comments`() throws {
        let source = Parser.parse(source:
            """
            /*
             Multi-line
             block comment
            */
            protocol Example {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)

        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "Example",
            localName: "Example",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: false,
            comment: "/*\n Multi-line\n block comment\n*/\n"
        ))
    }

    @Test
    func `collect extracts doc comments`() throws {
        let source = Parser.parse(source:
            """
            /**
             Documentation comment
             - Parameter x: Some param
            */
            protocol Example {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)

        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "Example",
            localName: "Example",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: false,
            comment: "/**\n Documentation comment\n - Parameter x: Some param\n*/\n"
        ))
    }

    @Test
    func `collect returns nil comment when only whitespace trivia`() throws {
        let source = Parser.parse(source:
            """


            protocol Example {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.comment == nil)
    }

    @Test
    func `collect handles multiple types in one file`() {
        let source = Parser.parse(source:
            """
            public protocol Service {}
            private struct Implementation: Service {}
            open class BaseClass {}
            internal enum Status { case active }
            extension Service {}
            """
        )

        let types = collector.collect(from: source)
        #expect(types == [
            Syntax.TypeInfo(
                kind: .protocol,
                name: "Service",
                localName: "Service",
                accessLevel: .public,
                inheritedTypes: [],
                isExtension: false,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .struct,
                name: "Implementation",
                localName: "Implementation",
                accessLevel: .private,
                inheritedTypes: ["Service"],
                isExtension: false,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .class,
                name: "BaseClass",
                localName: "BaseClass",
                accessLevel: .open,
                inheritedTypes: [],
                isExtension: false,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .enum,
                name: "Status",
                localName: "Status",
                accessLevel: .internal,
                inheritedTypes: [],
                isExtension: false,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .extension,
                name: "Service",
                localName: "Service",
                accessLevel: .internal,
                inheritedTypes: [],
                isExtension: true,
                comment: nil
            )
        ])
    }
}
