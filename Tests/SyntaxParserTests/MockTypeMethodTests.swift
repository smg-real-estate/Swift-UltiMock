import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

struct MockTypeMethodTests {
    @Test(arguments: [
        ("func noParamsVoid()", "noParamsVoid_sync_ret_Void"),
        ("func withParams(label name: Int, nameAsLabel: Double, _ anonymous: String)", "withParams_label_Int_nameAsLabel_Double__String_sync_ret_Void"),
        ("func returnsValue() -> Bool", "returnsValue_ret_Bool"),
        ("func throwsError() throws", "throwsError_sync_throws_ret_Void"),
        ("func asyncFunction() async", "asyncFunction_async_ret_Void"),
        ("func `switch`()", "switch_sync_ret_Void"),
        ("func complex(_ value: Int) async throws -> String", "complex_async__value_Int_async_throws_ret_String"),
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
}
