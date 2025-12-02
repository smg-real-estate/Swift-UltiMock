//
//  Test.swift
//  UltiMock
//
//  Created by Mykola Tarbaiev on 02.12.25.
//

import Testing
@testable import SyntaxParser
import SwiftParser
import SwiftSyntax

struct MockTypeMethodTests {
    @Test(arguments: [
        ("func noParamsVoid()", "noParamsVoid_sync_ret_Void"),
        ("func withParams(label name: Int, _ anonymous: String)", "withParams_label_Int__String_sync_ret_Void"),
        ("func returnsValue() -> Bool", "returnsValue_ret_Bool"),
        ("func throwsError() throws", "throwsError_sync_throws_ret_Void"),
        ("func asyncFunction() async", "asyncFunction_async_ret_Void"),
        ("func `switch`()", "switch_sync_ret_Void"),
        ("func complex(_ value: Int) async throws -> String", "complex_async__value_Int_async_throws_ret_String"),
    ])
    func `stubIdentifier maps non-textual information`(source: String, expectedIdentifier: String) async throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(FunctionDeclSyntax(syntax))

        let sut = MockType.Method(declaration: declaration)

        #expect(sut.stubIdentifier == expectedIdentifier)
    }
}
