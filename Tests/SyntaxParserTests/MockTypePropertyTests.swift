import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

struct MockTypePropertyTests {
    @Test(arguments: [
        ("var property: Int { get }", "property_get_Int"),
        ("var property: Int { get set }", "property_get_set_Int"),
        ("var property: Int { get throws }", "property_get_throws_Int"),
        ("var property: Int { get async }", "property_get_async_Int"),
        ("var property: Int { get async throws }", "property_get_async_throws_Int"),
    ])
    func `stubIdentifier maps non-textual information`(source: String, expectedIdentifier: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration)

        #expect(sut.stubIdentifier == expectedIdentifier)
    }

    @Test func `implementation for readonly`() throws {
        let syntax = Parser.parse(source: "var readonly: Int { get }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration)

        #expect(sut.implementation().formatted().description == """
        var readonly: Int {
            get {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () -> Int
                return perform()
            }
        }
        """)
    }

    @Test func `implementation for readonly throwing`() throws {
        let syntax = Parser.parse(source: "var readonlyThrowing: Double { get throws }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration)

        #expect(sut.implementation().formatted().description == """
        var readonlyThrowing: Double {
            get throws {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () throws -> Double
                return try perform()
            }
        }
        """)
    }

    @Test func `implementation for readonly async`() throws {
        let syntax = Parser.parse(source: "var readonlyAsync: String { get async }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration)

        #expect(sut.implementation().formatted().description == """
        var readonlyAsync: String {
            get async {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () throws -> String
                return await perform()
            }
        }
        """)
    }

    @Test func `implementation for readonly async throwing`() throws {
        let syntax = Parser.parse(source: "var readonlyAsyncThrowing: Int { get async throws }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration)

        #expect(sut.implementation().formatted().description == """
        var readonlyAsyncThrowing: Int {
            get async throws {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () throws -> Int
                return try await perform()
            }
        }
        """)
    }

    @Test func `implementation for readwrite`() throws {
        let syntax = Parser.parse(source: "var readwrite: Int { get set }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration)

        #expect(sut.implementation().formatted().description == """
        var readwrite: Int {
            get {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () -> Void
                return perform()
            }
            set {
                let perform = _perform(
                    Methods.set_\(sut.stubIdentifier),
                    [newValue]
                ) as! (_ newValue: Int) -> Int
                return perform(newValue)
            }
        }
        """)
    }
}
