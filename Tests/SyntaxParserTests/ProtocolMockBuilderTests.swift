import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

struct ProtocolMockBuilderTests {
    @Test func `mockClass contains correct declaration for a simple protocol`() throws {
        let source = Parser.parse(source: """
        protocol TestProtocol {
            func doSomething() -> Int
        }
        """)

        let declaration = try #require(source.statements.first?.item.as(ProtocolDeclSyntax.self))

        let sut = MockedProtocol(declaration: declaration, inherited: []).mockBuilder

        #expect(sut.mockClass.withoutMembers().description == """
        class TestProtocolMock: Mock, @unchecked Sendable {
        }
        """)
    }

    @Test func `mockClass contains correct declaration for a protocol with associated types`() throws {
        let source = Parser.parse(source: """
        protocol TestProtocol {
            associatedtype Item
            associatedtype Identifier: Hashable

            func doSomething() -> Int
        }
        """)

        let declaration = try #require(source.statements.first?.item.as(ProtocolDeclSyntax.self))

        let sut = MockedProtocol(declaration: declaration, inherited: []).mockBuilder

        #expect(sut.mockClass.withoutMembers().description == """
        class TestProtocolMock<Item, Identifier: Hashable>: Mock, @unchecked Sendable {
        }
        """)
    }

    @Test func `mockClass contains declaration with generic parameters from inherited protocol with associated types`() {
        let source = Parser.parse(source: """
        protocol Foo {
            associatedtype Item: Hashable, Codable
            associatedtype Identifier: Hashable

            func doSomething() -> Int
        }

        protocol Bar: Foo {}
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[1], inherited: [types[0]]).mockBuilder

        #expect(sut.mockClass.withoutMembers().description == """
        class BarMock<Item: Hashable & Codable, Identifier: Hashable>: Mock, @unchecked Sendable {
        }
        """)
    }

    @Test func `methodsEnum contains stub identifiers for all methods`() {
        let source = Parser.parse(source: """
        protocol Foo {
            func doSomething() -> Int
        }

        protocol Bar: Foo {
            func doSomethingElse<T>(with: T) async throws -> String where T: Equatable
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[1], inherited: [types[0]]).mockBuilder

        #expect(sut.methodsEnum.description == """

        enum Methods {
            static var doSomething_ret_Int: MockMethod {
                .init {
                    "doSomething()"
                }
            }
            static var doSomethingElse_async_with_T_async_throws_ret_String_where_T_con_Equatable: MockMethod {
                .init {
                    "doSomethingElse<T>(with: \\($0[0] ?? "nil"))"
                }
            }
        }
        """)
    }
}

extension ClassDeclSyntax {
    func withoutMembers() -> ClassDeclSyntax {
        with(\.memberBlock.members, [])
    }
}

extension MockedProtocol {
    var mockBuilder: ProtocolMockBuilder {
        ProtocolMockBuilder(self)
    }
}
