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
        class TestProtocolMock: Mock, TestProtocol, @unchecked Sendable {
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
        class TestProtocolMock<Item, Identifier: Hashable>: Mock, TestProtocol, @unchecked Sendable {
        typealias Item = Item 
        typealias Identifier = Identifier 
        }
        """)
    }

    @Test func `mockClass contains correct declaration for a public protocol with associated types`() throws {
        let source = Parser.parse(source: """
        public protocol TestProtocol {
            associatedtype Item
            associatedtype Identifier: Hashable

            func doSomething() -> Int
        }
        """)

        let declaration = try #require(source.statements.first?.item.as(ProtocolDeclSyntax.self))

        let sut = MockedProtocol(declaration: declaration, inherited: []).mockBuilder

        #expect(sut.mockClass.withoutMembers().description == """
        open class TestProtocolMock<Item, Identifier: Hashable>: Mock, TestProtocol, @unchecked Sendable {
        public typealias Item = Item 
        public typealias Identifier = Identifier 
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
        class BarMock<Item: Hashable & Codable, Identifier: Hashable>: Mock, Bar, @unchecked Sendable {
        typealias Item = Item 
        typealias Identifier = Identifier 
        }
        """)
    }

    @Test func `mockClass is open for public protocol`() throws {
        let source = Parser.parse(source: """
        public protocol PublicProtocol {}
        """)

        let declaration = try #require(source.statements.first?.item.as(ProtocolDeclSyntax.self))

        let sut = MockedProtocol(declaration: declaration, inherited: []).mockBuilder

        #expect(sut.mockClass.withoutMembers().description == """
        open class PublicProtocolMock: Mock, PublicProtocol, @unchecked Sendable {
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

        #expect(sut.methodsEnum.formatted().description == """

        enum Methods {
            static var doSomething_ret_Int: MockMethod {
                .init { _ in
                    "doSomething()"
                }
            }
            static var doSomethingElse_async_with_T_async_throws_ret_String_where_T_con_Equatable: MockMethod {
                .init {
                    "doSomethingElse<T>(with: \\($0 [0] ?? "nil"))"
                }
            }
        }
        """)
    }

    @Test func `methodsEnum contains stub identifiers for all properties`() {
        let source = Parser.parse(source: """
        protocol Foo {
            var readonly: Int { get }
        }

        protocol Bar: Foo {
            var readwrite: String { get set }
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[1], inherited: [types[0]]).mockBuilder

        #expect(sut.methodsEnum.formatted().description == """

        enum Methods {
            static var get_readonly_Int: MockMethod {
                .init { _ in
                    "readonly"
                }
            }
            static var get_readwrite_String: MockMethod {
                .init { _ in
                    "readwrite"
                }
            }
            static var set_readwrite_String: MockMethod {
                .init {
                    "readwrite = \\($0 [0] ?? "nil")"
                }
            }
        }
        """)
    }

    @Test(arguments: [
        "",
        "public "
    ]) func `propertyExpectation contains correct declaration`(accessModifier: String) throws {
        let source = Parser.parse(source: """
        \(accessModifier)protocol Foo {
            func doSomething() -> Int // Some comment 
        }
        """)

        let declaration = try #require(source.statements.first?.item.as(ProtocolDeclSyntax.self))

        let sut = MockedProtocol(declaration: declaration, inherited: []).mockBuilder

        #expect(sut.propertyExpectationsStruct.formatted().description == """
        \(accessModifier)struct PropertyExpectation<Signature> {
            private let method: MockMethod

            init(method: MockMethod) {
                self.method = method
            }

            \(accessModifier)var getterExpectation: Recorder.Expectation {
                .init(
                    method: method,
                    parameters: []
                )
            }

            \(accessModifier)func setterExpectation(_ newValue: AnyParameter) -> Recorder.Expectation {
                .init(
                    method: method,
                    parameters: [newValue]
                )
            }
        }
        """)
    }

    @Test(arguments: [
        "",
        "public "
    ]) func `methodExpectation contains expectations for all methods`(accessModifier: String) {
        let source = Parser.parse(source: """
        \(accessModifier)protocol Foo {
            func doSomething() -> Int // Some comment 
        }

        protocol Bar: Foo {
            func doSomethingElse<T>(with: T) async throws -> String where T: Equatable
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[1], inherited: [types[0]]).mockBuilder

        #expect(sut.methodExpectationStruct.formatted().description == """

        \(accessModifier)struct MethodExpectation<Signature> {
            let expectation: Recorder.Expectation

            init(method: MockMethod, parameters: [AnyParameter]) {
                self.expectation = .init(
                    method: method,
                    parameters: parameters
                )
            }

            \(accessModifier)static func doSomething() -> Self where Signature == () -> Int {
                .init(
                    method: Methods.doSomething_ret_Int,
                    parameters: []
                )
            }

            \(accessModifier)static func doSomethingElse<T>(with: Parameter<T>) -> Self where Signature == (
                _ with: T
            ) -> String {
                .init(
                    method: Methods.doSomethingElse_async_with_T_async_throws_ret_String_where_T_con_Equatable,
                    parameters: [
                        with.anyParameter
                    ]
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

        #expect(sut.recordMethod.formatted().description == """
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

    @Test func `performMethod contains correct implementation`() {
        let source = Parser.parse(source: """
        protocol Foo {
            func doSomething()
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[0], inherited: []).mockBuilder

        #expect(sut.performMethod.formatted().description == """
        private func _perform(
            _ method: MockMethod,
            _ parameters: [Any?] = []
        ) -> Any {
            let invocation = Invocation(
                method: method,
                parameters: parameters
            )
            guard let stub = recorder.next() else {
                handleFatalFailure(
                    "Expected no calls but received `\\(invocation)`",
                    fileID: fileID,
                    filePath: filePath,
                    line: line,
                    column: column
                )
            }
            guard stub.matches(invocation) else {
                handleFatalFailure(
                    "Unexpected call: expected `\\(stub.expectation)`, but received `\\(invocation)`",
                    fileID: stub.fileID,
                    filePath: stub.filePath,
                    line: stub.line,
                    column: stub.column
                )
            }
            defer {
                recorder.checkVerification()
            }
            return stub.perform
        }
        """)
    }

    @Test(arguments: [
        "",
        "public "
    ]) func `implementationProperties contains property implementations`(accessModifier: String) throws {
        let source = Parser.parse(source: #"""
        \#(accessModifier)protocol Foo {
            var readonly: Int { get }
        }
        """#)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[0], inherited: []).mockBuilder

        let generatedMethod = try #require(sut.implementationProperties.first)

        #expect(
            generatedMethod.formatted().trimmedDescription == """
            \(accessModifier)var readonly: Int {
                get {
                    let perform = _perform(
                        Methods.get_readonly_Int
                    ) as! () -> Int
                    return perform()
                }
            }
            """
        )
    }

    @Test(arguments: [
        "",
        "public "
    ]) func `implementationMethods contains method implementations`(accessModifier: String) throws {
        let source = Parser.parse(source: #"""
        \#(accessModifier)protocol Foo {
            func make(value: Int) -> String
        }
        """#)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[0], inherited: []).mockBuilder

        let generatedMethod = try #require(sut.implementationMethods.first)

        #expect(
            generatedMethod.formatted().trimmedDescription == #"""
            \#(accessModifier)func make(value: Int) -> String {
                let perform = _perform(
                    Methods.make_value_Int_ret_String,
                    [value]
                ) as! (Int) -> String
                return perform(value)
            }
            """#
        )
    }

    @Test func `expectationSetters contains expect method declarations without duplicated signatures`() throws {
        let source = Parser.parse(source: """
        protocol Foo {
            func doSomething() -> Int
            func doSomethingElse() -> Int // Duplicated signature
            func doSomethingElse(with: String) async throws -> Bool
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[0], inherited: []).mockBuilder

        #expect(sut.expectationSetters.count == 2)

        let firstExpect = try #require(sut.expectationSetters.first)
        #expect(firstExpect.formatted().trimmedDescription == """
        public func expect(
            _ expectation: MethodExpectation<() -> Int>,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping () -> Int
        ) {
            _record(
                expectation.expectation,
                fileID,
                filePath,
                line,
                column,
                perform
            )
        }
        """)

        let secondExpect = try #require(sut.expectationSetters.last)
        #expect(secondExpect.formatted().trimmedDescription == """
        public func expect(
            _ expectation: MethodExpectation<(String) async throws -> Bool>,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping (String) async throws -> Bool
        ) {
            _record(
                expectation.expectation,
                fileID,
                filePath,
                line,
                column,
                perform
            )
        }
        """)
    }

    @Test func `expectationSetters contains property expect method declarations without duplicated signatures`() throws {
        let source = Parser.parse(source: """
        protocol Foo {
            var a: Int! { get }
            var b: Int! { get }
            var c: Int! { get async }
            var d: Int! { get throws }
            var d: Int! { get async throws }
            var e: Int! { get set }
        }
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[0], inherited: []).mockBuilder

        let result = sut.expectationSetters
        try #require(result.count == 5)
    }
}

extension ClassDeclSyntax {
    func withoutMembers() -> ClassDeclSyntax {
        with(\.memberBlock.members, memberBlock.members.filter { $0.decl.kind == .typeAliasDecl })
    }
}

extension MockedProtocol {
    var mockBuilder: ProtocolMockBuilder {
        ProtocolMockBuilder(self)
    }
}
