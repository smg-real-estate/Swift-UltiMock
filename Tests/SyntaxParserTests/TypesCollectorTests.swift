import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

@Suite struct TypesCollectorTests {
    let collector = TypesCollector()

    @Test
    func `collects protocol interface`() throws {
        let protocolSource = """
        protocol MyProtocol {
            func doSomething()
            var value: Int { get set }
        }
        """
        let source = Parser.parse(source: protocolSource)

        let types = collector.collect(from: source)

        try #require(types.count == 1)

        let type = types[0]
        #expect(type.scope == [])

        let expectedDeclaration = try declaration(from: protocolSource)
        #expect(type.declaration.description == expectedDeclaration.description)
    }

    @Test
    func `collects class interface without implementation`() throws {
        let classSource = """
        class MyClass {
            func doSomething() {
                print("Hello, World!")
            }

            let immutableProperty: Int = 42
            var mutableProperty: Int = 0
            var computedReadonly: Int {
                123
            }
            var computedReadwrite: Int {
                get { 456 }
                set { print(newValue) }
            }
        }
        """

        let source = Parser.parse(source: classSource)

        let types = collector.collect(from: source)

        try #require(types.count == 1)

        let type = types[0]
        #expect(type.scope == [])

        let expectedDeclaration = try declaration(from: """
        class MyClass {
            func doSomething() {}

            var immutableProperty: Int { get }
            var mutableProperty: Int { get set }
            var computedReadonly: Int { get }
            var computedReadwrite: Int { get set }
        }
        """)
        #expect(type.declaration.description == expectedDeclaration.description)
    }

    @Test
    func `collects multiple types`() throws {
        let protocolSource = """
        protocol MyProtocol {
            func doSomething()
            var value: Int { get set }
        }
        """

        let classSource = """
        class MyClass {
            func doSomething() {}
            var value: Int = 0
        }
        """

        let source = Parser.parse(source: [
            protocolSource,
            classSource
        ].joined(separator: "\n"))

        let types = collector.collect(from: source)

        #expect(types.count == 2)
    }
}

private extension TypesCollectorTests {
    final class TypeDeclarationVisitor: SyntaxVisitor {
        private(set) var declarations: [DeclSyntax] = []

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            declarations.append(DeclSyntax(node))
            return .skipChildren
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            declarations.append(DeclSyntax(node))
            return .skipChildren
        }
    }

    func declaration(from source: String) throws -> DeclSyntax {
        let syntax = Parser.parse(source: source)
        let visitor = TypeDeclarationVisitor(viewMode: .all)
        visitor.walk(syntax)
        return try #require(visitor.declarations.first)
    }
}
