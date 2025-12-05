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

    @Test func `methodExpectation contains expectations for all methods`() {
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

        #expect(sut.methodExpectations.description == """

        struct MethodExpectation<Signature> {
            let expectation: Recorder.Expectation

            init(method: MockMethod, parameters: [AnyParameter]) {
                self.expectation = .init(
                    method: method,
                    parameters: parameters
                )
            }

            static func doSomething() -> Self
            where Signature == () -> Void {
                .init(
                    method: Methods.doSomething_ret_Int,
                    parameters: []
                )
            }

            static func doSomethingElse<T>(with: Parameter<T>) -> Self
            where Signature == (_ with: T) -> Void {
                .init(
                    method: Methods.doSomethingElse_async_with_T_async_throws_ret_String_where_T_con_Equatable,
                    parameters: [with.anyParameter]
                )
            }
        }
        """)
    }

    @Test func `properties is comprehensive`() {
        let source = Parser.parse(source: """
        protocol Foo {
            func doSomething() -> Int
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[0], inherited: []).mockBuilder

        #expect(MemberBlockItemListSyntax(sut.properties).description == """

        public let recorder = Recorder()

        private let fileID: String
        private let filePath: StaticString
        private let line: UInt
        private let column: Int
        """)
    }

    @Test func `initializer is correct`() {
        let source = Parser.parse(source: """
        protocol Foo {
            func doSomething() -> Int
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[0], inherited: []).mockBuilder

        #expect(sut.initializer.description == """

        public init(
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column
        ) {
            self.fileID = fileID
            self.filePath = filePath
            self.line = line
            self.column = column
        }
        """)
    }

    @Test func `recordMethod is correct`() {
        let source = Parser.parse(source: """
        protocol Foo {
            func doSomething() -> Int
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[0], inherited: []).mockBuilder

        #expect(sut.recordMethod.description == """
        private func _record<P>(
            _ expectation: Recorder.Expectation,
            _ fileID: String,
            _ filePath: StaticString,
            _ line: UInt,
            _ column: Int,
            _ perform: P
        ) {
            guard isEnabled else {
                handleFatalFailure(
                    "Setting expectation on disabled mock is not allowed",
                    fileID: fileID,
                    filePath: filePath,
                    line: line,
                    column: column
                )
            }
            recorder.record(
                .init(
                    expectation,
                    perform,
                    fileID,
                    filePath,
                    line,
                    column
                )
            )
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
