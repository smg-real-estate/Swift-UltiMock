import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

struct MockTypeMethodTests {
    @Test(arguments: [
        ("func noParamsVoid()", "noParamsVoid_sync_ret_Void"),
        ("// Leading trivia\nfunc withTrivia() -> Void // Trailing trivia", "withTrivia_sync_ret_Void"),
        ("func withParams(label name: Int, nameAsLabel: Double, _ anonymous: String)", "withParams_label_Int_nameAsLabel_Double___String_sync_ret_Void"),
        ("func returnsValue() -> Bool", "returnsValue_ret_Bool"),
        ("func throwsError() throws", "throwsError_sync_throws_ret_Void"),
        ("func asyncFunction() async", "asyncFunction_async_ret_Void"),
        ("func `switch`()", "switch_sync_ret_Void"),
        ("func optionalResult() -> String?)", "optionalResult_ret_String_opt"),
        ("func forceUnwrappedResult() -> String!)", "forceUnwrappedResult_ret_String_impopt"),
        ("func withOptionalParameter(_ string: String?)", "withOptionalParameter___String_opt_sync_ret_Void"),
        ("func withForceUnwrappedParameter(_ string: String!)", "withForceUnwrappedParameter___String_impopt_sync_ret_Void"),
        ("func withNamespaced(_ a: Foo.A) -> Bar.B", "withNamespaced___Foo_dot_A_ret_Bar_dot_B"),
        ("func withArrayLiterals(_ a: [Foo.A]) -> [Bar.B]", "withArrayLiterals___lsb_Foo_dot_A_rsb_ret_lsb_Bar_dot_B_rsb"),
        ("func withDictionaryLiterals(_ a: [String : Foo.A]) -> [Foo.A:Bar.B]", "withDictionaryLiterals___lsb_String_col_Foo_dot_A_rsb_ret_lsb_Foo_dot_A_col_Bar_dot_B_rsb"),
        ("func complex(_ value: Int) async throws -> String", "complex_async___Int_async_throws_ret_String"),
        ("func withGenericConstraints<A>(a: A, b: B) where A: Codable, B == Int", "withGenericConstraints_a_A_b_B_sync_ret_Void_where_A_con_Codable_B_eq_Int"),
        ("func withClosure(_ closure: (Int) -> Void)", "withClosure___lpar_Int_rpar_ret_Void_sync_ret_Void"),
        ("func withThrowingClosure(_ closure: (String) throws -> Bool)", "withThrowingClosure___lpar_String_rpar_throws_ret_Bool_sync_ret_Void"),
        ("func withAsyncClosure(_ closure: (Int) async -> String)", "withAsyncClosure___lpar_Int_rpar_async_ret_String_sync_ret_Void"),
        ("func withEscapingClosure(_ closure: @escaping () -> Void)", "withEscapingClosure___lpar_rpar_ret_Void_sync_ret_Void"),
        ("func withAutoclosure(_ closure: @autoclosure () -> String)", "withAutoclosure___lpar_rpar_ret_String_sync_ret_Void"),
        ("func withEscapingAutoclosure(_ closure: @escaping @autoclosure () -> Int)", "withEscapingAutoclosure___lpar_rpar_ret_Int_sync_ret_Void"),
        ("func withMultipleClosures(_ a: (Int) -> String, _ b: @escaping (Bool) -> Void)", "withMultipleClosures___lpar_Int_rpar_ret_String___lpar_Bool_rpar_ret_Void_sync_ret_Void"),
        ("func withOptionalClosure(_ closure: ((String) -> Int)?)", "withOptionalClosure___lpar_String_rpar_ret_Int_opt_sync_ret_Void"),
        ("func returningClosure() -> (Int) -> String", "returningClosure_ret_lpar_Int_rpar_ret_String"),
        ("func generic(some: some TestGenericProtocol<Int>, any: any TestGenericProtocol<String>) -> Int", "generic_some_some_TestGenericProtocol_lab_Int_rab_any_any_TestGenericProtocol_lab_String_rab_ret_Int"),
        ("func doSomethingWithInput<I, O>(_ input: I) -> O where Value == (I) -> O", "doSomethingWithInput___I_ret_O_where_Value_eq_lpar_I_rpar_ret_O"),
    ])
    func `stubIdentifier maps non-textual information`(source: String, expectedIdentifier: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.stubIdentifier == expectedIdentifier)
    }

    @Test func `implementation emits simple body without trailing trivia`() throws {
        let syntax = Parser.parse(source: "func make(value: Int) -> String // Trailing trivia").statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation().formatted().description == #"""
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

        #expect(sut.implementation().formatted().description == #"""
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

        #expect(sut.implementation().formatted().description == #"""
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
            ) as! (_ int: Swift.Int, _ labelString: String, _ string: String, _ optional: Int?, _ implicitOptional: Int?, _ `inout`: inout Int, _ array: [Int], _ dictionary: [String: Int], _ escapingClosure: @escaping (Int) -> Void) -> Void
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

        #expect(sut.implementation().formatted().description == #"""
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

        #expect(sut.implementation().formatted().description == #"""
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

        #expect(sut.implementation().formatted().description == #"""
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

        #expect(sut.implementation().formatted().description == #"""
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

        #expect(sut.implementation().formatted().description == #"""
        @discardableResult
        func discardableResult() -> String {
            let perform = _perform(
                Methods.\#(sut.stubIdentifier)
            ) as! () -> String
            return perform()
        }
        """#)
    }

    @Test func `implementation emits correct body for force-unwrapped parameters and result`() throws {
        let syntax = Parser.parse(source: #"""
        func forceUnwrappedResult(_ optional: Int!) -> String!
        """#).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation().formatted().description == #"""
        func forceUnwrappedResult(_ optional: Int!) -> String! {
            let perform = _perform(
                Methods.\#(sut.stubIdentifier),
                [optional]
            ) as! (_ optional: Int?) -> String?
            return perform(optional)
        }
        """#)
    }

    @Test func `implementation replaces Self parameter type with mock name`() throws {
        let syntax = Parser.parse(source: #"""
        func withSelf(_ self: Self) -> Self
        """#).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation(in: "TestMock").formatted().description == #"""
        func withSelf(_ self: TestMock) -> Self {
            let perform = _perform(
                Methods.\#(sut.stubIdentifier),
                [self]
            ) as! (_ self: TestMock) -> Self
            return perform(self)
        }
        """#)
    }

    @Test func `implementation replaces some with any`() throws {
        let syntax = Parser.parse(source: #"""
        func withSome(_ some: some TestGenericProtocol<Int>)
        """#).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.implementation(in: "TestMock").formatted().description == #"""
        func withSome(_ some: some TestGenericProtocol<Int>) {
            let perform = _perform(
                Methods.\#(sut.stubIdentifier),
                [some]
            ) as! (_ some: any TestGenericProtocol<Int>) -> Void
            return perform(some)
        }
        """#)
    }

    @Test func `expect emits correct method for simple function`() throws {
        let syntax = Parser.parse(source: "func foo()").statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.expect.formatted().description == """
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

        #expect(sut.expect.formatted().description == """
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

        #expect(sut.expect.formatted().description == """
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

    @Test func `expectationMethodDeclaration emits correct method`() throws {
        let syntax = Parser.parse(source: """
        func withParamsVoid(
            int: Swift.Int,
            label labelString: String,
            _ self: Self,
            _ string: String,
            _ optional: Int?,
            _ implicitOptional: Int!,
            _ `inout`: inout Int,
            _ array: [Int],
            _ dictionary: [String: Int],
            _ escapingClosure: @escaping (Int) -> Void
        )
        """).statements.first?.item

        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        let mockClassName = "MockableMock"

        #expect(sut.expectationMethodDeclaration(mockName: mockClassName).formatted().description == """
        static func withParamsVoid(
            int: Parameter<Swift.Int>,
            label labelString: Parameter<String>,
            _ self: Parameter<MockableMock>,
            _ string: Parameter<String>,
            _ optional: Parameter<Int?>,
            _ implicitOptional: Parameter<Int?>,
            _ `inout`: Parameter<Int>,
            _ array: Parameter<[Int]>,
            _ dictionary: Parameter<[String: Int]>,
            _ escapingClosure: Parameter<(Int) -> Void>
        ) -> Self where Signature == (
            _ int: Swift.Int,
            _ labelString: String,
            _ string: String,
            _ optional: Int?,
            _ implicitOptional: Int?,
            _ `inout`: inout Int,
            _ array: [Int],
            _ dictionary: [String: Int],
            _ escapingClosure: (Int) -> Void
        ) -> Void {
            .init(
                method: Methods.withParamsVoid_int_Swift_dot_Int_label_String___Self___String___Int_opt___Int_impopt___Int___lsb_Int_rsb___lsb_String_col_Int_rsb___lpar_Int_rpar_ret_Void_sync_ret_Void,
                parameters: [
                    int.anyParameter,
                    labelString.anyParameter,
                    string.anyParameter,
                    optional.anyParameter,
                    implicitOptional.anyParameter,
                    `inout`.anyParameter,
                    array.anyParameter,
                    dictionary.anyParameter,
                    escapingClosure.anyParameter
                ]
            )
        }
        """)
    }

    @Test func `expectationMethodDeclaration contains generic return type`() throws {
        let syntax = Parser.parse(source: """
        func withGenerics<A, B>(_ a: A) -> B
        """).statements.first?.item

        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        let mockClassName = "MockableMock"

        #expect(sut.expectationMethodDeclaration(mockName: mockClassName).formatted().description == """
        static func withGenerics<A, B>(_ a: Parameter<A>) -> Self where Signature == (
            _ a: A
        ) -> B {
            .init(
                method: Methods.withGenerics___A_ret_B,
                parameters: [
                    a.anyParameter
                ]
            )
        }
        """)
    }

    @Test func `expectationMethodDeclaration replaces some with any`() throws {
        let syntax = Parser.parse(source: """
        func withSome(_ some: some TestGenericProtocol<Int>)
        """).statements.first?.item

        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        let mockClassName = "MockableMock"

        #expect(sut.expectationMethodDeclaration(mockName: mockClassName).formatted().description == #"""
        static func withSome(_ some: Parameter<any TestGenericProtocol<Int>>) -> Self where Signature == (
            _ some: any TestGenericProtocol<Int>
        ) -> Void {
            .init(
                method: Methods.\#(sut.stubIdentifier),
                parameters: [
                    some.anyParameter
                ]
            )
        }
        """#)
    }

    @Test func `expectationMethodDeclaration escapes keywords`() throws {
        let syntax = Parser.parse(source: """
        func withKeywords(_ internal: Int, _ `inout`: Int)
        """).statements.first?.item

        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        let mockClassName = "MockableMock"

        #expect(sut.expectationMethodDeclaration(mockName: mockClassName).formatted().description == #"""
        static func withKeywords(_ `internal`: Parameter<Int>, _ `inout`: Parameter<Int>) -> Self where Signature == (
            _ `internal`: Int,
            _ `inout`: Int
        ) -> Void {
            .init(
                method: Methods.\#(sut.stubIdentifier),
                parameters: [
                    `internal`.anyParameter,
                    `inout`.anyParameter
                ]
            )
        }
        """#)
    }
}
