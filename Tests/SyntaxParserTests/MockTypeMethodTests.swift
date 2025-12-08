import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

struct MockTypeMethodTests {
    @Test(arguments: [
        ("func noParamsVoid()", "noParamsVoid_sync_ret_Void"),
        ("func withParams(label name: Int, nameAsLabel: Double, _ anonymous: String)", "withParams_label_Int_nameAsLabel_Double___String_sync_ret_Void"),
        ("func returnsValue() -> Bool", "returnsValue_ret_Bool"),
        ("func throwsError() throws", "throwsError_sync_throws_ret_Void"),
        ("func asyncFunction() async", "asyncFunction_async_ret_Void"),
        ("func `switch`()", "switch_sync_ret_Void"),
        ("func complex(_ value: Int) async throws -> String", "complex_async___Int_async_throws_ret_String"),
        ("func withGenericConstraints<A>(a: A, b: B) where A: Codable, B == Int", "withGenericConstraints_a_A_b_B_sync_ret_Void_where_A_con_Codable_B_eq_Int"),
    ])
    func `stubIdentifier maps non-textual information`(source: String, expectedIdentifier: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.stubIdentifier == expectedIdentifier)
    }

    @Test func `implementation emits simple body`() throws {
        let syntax = Parser.parse(source: "func make(value: Int) -> String").statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation.description == #"""
        func make(value: Int) -> String {
            let perform = _perform(
                    Methods.\#(sut.stubIdentifier),
                    [value]
                ) as! (_ value: Int) -> String
            return perform(value)
        }
        """#)
    }

    @Test func `implementation keeps async throws semantics`() throws {
        let syntax = Parser.parse(source: "func make(label name: String, _ other: Int) async throws -> Void").statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation.description == #"""
        func make(label name: String, _ other: Int) async throws -> Void {
            let perform = _perform(
                    Methods.\#(sut.stubIdentifier),
                    [name, other]
                ) as! (_ name: String, _ other: Int) async throws -> Void
            return try await perform(name, other)
        }
        """#)
    }

    @Test func `implementation emits correct body for complex parameters`() throws {
        let syntax = Parser.parse(source: #"""
        func withParamsVoid(
            int: Swift.Int,
            label labelString: String,
            _ string: String,
            _ optional: Int?,
            _ implicitOptional: Int!,
            _ `inout`: inout Int,
            _ array: [Int],
            _ dictionary: [String: Int],
            _ escapingClosure: @escaping (Int) -> Void
        )
        """#).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation.description == #"""
        func withParamsVoid(
            int: Swift.Int,
            label labelString: String,
            _ string: String,
            _ optional: Int?,
            _ implicitOptional: Int!,
            _ `inout`: inout Int,
            _ array: [Int],
            _ dictionary: [String: Int],
            _ escapingClosure: @escaping (Int) -> Void
        ) {
            let perform = _perform(
                    Methods.\#(sut.stubIdentifier),
                    [int, labelString, string, optional, implicitOptional, `inout`, array, dictionary, escapingClosure]
                ) as! (_ int: Swift.Int, _ labelString: String, _ string: String, _ optional: Int?, _ implicitOptional: Int!, _ `inout`: inout Int, _ array: [Int], _ dictionary: [String: Int], _ escapingClosure: @escaping (Int) -> Void) -> Void
            return perform(int, labelString, string, optional, implicitOptional, &`inout`, array, dictionary, escapingClosure)
        }
        """#)
    }

    @Test func `implementation emits correct body for generics`() throws {
        let syntax = Parser.parse(source: #"""
        func generic<P1: Equatable, P2>(
            parameter1: P1,
            _ parameter2: P2
        ) -> Int where P2: Hashable
        """#).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation.description == #"""
        func generic<P1: Equatable, P2>(
            parameter1: P1,
            _ parameter2: P2
        ) -> Int where P2: Hashable {
            let perform = _perform(
                    Methods.\#(sut.stubIdentifier),
                    [parameter1, parameter2]
                ) as! (_ parameter1: P1, _ parameter2: P2) -> Int
            return perform(parameter1, parameter2)
        }
        """#)
    }

    @Test func `implementation emits correct body for generics with equality constraint`() throws {
        let syntax = Parser.parse(source: #"""
        func withGenericConstraints<A>(a: A, b: B) where A: Codable, B == Int
        """#).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation.description == #"""
        func withGenericConstraints<A>(a: A, b: B) where A: Codable, B == Int {
            let perform = _perform(
                    Methods.\#(sut.stubIdentifier),
                    [a, b]
                ) as! (_ a: A, _ b: B) -> Void
            return perform(a, b)
        }
        """#)
    }

    @Test func `implementation emits correct body for annotated closure`() throws {
        let syntax = Parser.parse(source: #"""
        func withAnnotatedClosure(
            _ closure: (@MainActor @Sendable (Int) -> Void)?
        )
        """#).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation.description == #"""
        func withAnnotatedClosure(
            _ closure: (@MainActor @Sendable (Int) -> Void)?
        ) {
            let perform = _perform(
                    Methods.\#(sut.stubIdentifier),
                    [closure]
                ) as! (_ closure: (@MainActor @Sendable (Int) -> Void)?) -> Void
            return perform(closure)
        }
        """#)
    }

    @Test func `implementation emits correct body for self parameter`() throws {
        let syntax = Parser.parse(source: "func withSelf(_ `self`: TestMockableMock) -> TestMockableMock").statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation.description == #"""
        func withSelf(_ `self`: TestMockableMock) -> TestMockableMock {
            let perform = _perform(
                    Methods.\#(sut.stubIdentifier),
                    [`self`]
                ) as! (_ `self`: TestMockableMock) -> TestMockableMock
            return perform(`self`)
        }
        """#)
    }

    @Test func `implementation emits correct body for discardable result`() throws {
        let syntax = Parser.parse(source: #"""
        @discardableResult
        func discardableResult() -> String
        """#).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation.description == #"""
        @discardableResult
        func discardableResult() -> String {
            let perform = _perform(
                    Methods.\#(sut.stubIdentifier)
                ) as! () -> String
            return perform()
        }
        """#)
    }

    @Test func `expect emits correct method for simple function`() throws {
        let syntax = Parser.parse(source: "func foo()").statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.expect.description == """
        public func expect(
            _ expectation: MethodExpectation<() -> Void>,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping () -> Void
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

    @Test func `expect emits correct method for function with parameters and return`() throws {
        let syntax = Parser.parse(source: "func foo(bar: Int) -> String").statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.expect.description == """
        public func expect(
            _ expectation: MethodExpectation<(_ bar: Int) -> String>,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping (_ bar: Int) -> String
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

    @Test func `expect emits correct method for async throws function`() throws {
        let syntax = Parser.parse(source: "func foo() async throws").statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.expect.description == """
        public func expect(
            _ expectation: MethodExpectation<() async throws -> Void>,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping () async throws -> Void
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
}
