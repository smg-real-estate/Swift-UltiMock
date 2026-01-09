import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

struct MockTypeSubscriptTests {
    @Test(arguments: [
        ("subscript(key: Int) -> String { get }", "subscript_get_key_key_Int_String"),
        ("subscript(key: Int) -> String { get set }", "subscript_get_key_key_Int_String"),
        ("subscript(key: String) -> Int? { get }", "subscript_get_key_key_String_Int_opt"),
        ("subscript(key: String!) -> Int! { get set }", "subscript_get_key_key_String_impopt_Int_impopt"),
        ("subscript(_ index: Int) -> String { get }", "subscript_get___index_Int_String"),
        ("subscript(key: Int, secondary: String) -> Bool { get }", "subscript_get_key_key_Int_secondary_secondary_String_Bool"),
    ])
    func `getterStubIdentifier maps subscript correctly`(source: String, expectedIdentifier: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterStubIdentifier == expectedIdentifier)
    }

    @Test(arguments: [
        ("subscript(key: Int) -> String { get set }", "subscript_set_key_key_Int_String"),
        ("subscript(_ index: Int) -> String { get set }", "subscript_set___index_Int_String"),
    ])
    func `setterStubIdentifier maps subscript correctly`(source: String, expectedIdentifier: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterStubIdentifier == expectedIdentifier)
    }

    @Test func `callDescription for single parameter`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.callDescription == #"[key: \($0[0] ?? "nil")]"#)
    }

    @Test func `callDescription for anonymous parameter`() throws {
        let syntax = Parser.parse(source: "subscript(_ index: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.callDescription == #"[\($0[0] ?? "nil")]"#)
    }

    @Test func `callDescription for multiple parameters`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int, secondary: String) -> Bool { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.callDescription == #"[key: \($0[0] ?? "nil"), secondary: \($0[1] ?? "nil")]"#)
    }

    @Test func `setterCallDescription includes newValue`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterCallDescription == #"[key: \($0[0] ?? "nil")] = \($0.last! ?? "nil")"#)
    }

    @Test func `hasSet returns false for readonly subscript`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(!sut.hasSet)
    }

    @Test func `hasSet returns true for readwrite subscript`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.hasSet)
    }

    @Test func `implementation for readonly subscript`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.implementation().formatted().description
        #expect(result.contains("subscript(key: Int) -> String"))
        #expect(result.contains("get {"))
        #expect(result.contains("_perform("))
        #expect(result.contains("Methods.\(sut.getterStubIdentifier)"))
        #expect(result.contains("[key]"))
        #expect(result.contains("as! (Int) -> String"))
        #expect(result.contains("return perform(key)"))
    }

    @Test func `implementation for readwrite subscript`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.implementation().formatted().description
        #expect(result.contains("subscript(key: Int) -> String"))
        #expect(result.contains("get {"))
        #expect(result.contains("set {"))
        #expect(result.contains("Methods.\(sut.getterStubIdentifier)"))
        #expect(result.contains("Methods.\(sut.setterStubIdentifier)"))
        #expect(result.contains("[key, newValue]"))
        #expect(result.contains("return perform(key, newValue)"))
    }

    @Test func `implementation for anonymous parameter subscript`() throws {
        let syntax = Parser.parse(source: "subscript(_ index: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.implementation().formatted().description
        #expect(result.contains("subscript(_ index: Int) -> String"))
        #expect(result.contains("get {"))
        #expect(result.contains("_perform("))
        #expect(result.contains("[index]"))
        #expect(result.contains("as! (Int) -> String"))
        #expect(result.contains("return perform(index)"))
    }

    @Test func `implementation replaces implicit optional with optional`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String! { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.implementation().formatted().description
        #expect(result.contains("subscript(key: Int) -> String!"))
        #expect(result.contains("as! (Int) -> String?"))
        #expect(result.contains("as! (Int, String?) -> Void"))
    }

    @Test func `getterVariableDeclaration generates correct method stub`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.getterVariableDeclaration.formatted().description
        #expect(result.contains("static var \(sut.getterStubIdentifier): MockMethod"))
        #expect(result.contains(".init {"))
        #expect(result.contains("[key:"))
    }

    @Test func `setterVariableDeclaration generates correct method stub`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = try #require(sut.setterVariableDeclaration?.formatted().description)
        #expect(result.contains("static var \(sut.setterStubIdentifier): MockMethod"))
        #expect(result.contains(".init {"))
        #expect(result.contains("[key:"))
        #expect(result.contains("$0.last!"))
    }

    @Test func `setterVariableDeclaration returns nil for readonly subscript`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterVariableDeclaration == nil)
    }

    @Test func `getterExpect generates correct expect function`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.getterExpect.formatted().description
        #expect(result.contains("public func expect("))
        #expect(result.contains("_ expectation: SubscriptExpectation<(Int) -> String"))
        #expect(result.contains("fileID: String = #fileID"))
        #expect(result.contains("perform: @escaping (Int) -> String"))
        #expect(result.contains("_record("))
        #expect(result.contains("expectation.getterExpectation"))
    }

    @Test func `setterExpect generates correct expect function`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.setterExpect.formatted().description
        #expect(result.contains("public func expect("))
        #expect(result.contains("set expectation: SubscriptExpectation<(Int, String"))
        #expect(result.contains("to newValue: Parameter<String"))
        #expect(result.contains("perform: @escaping (Int, String"))
        #expect(result.contains("_record("))
        #expect(result.contains("expectation.setterExpectation(newValue.anyParameter)"))
    }

    @Test func `subscriptExpectationsSubscript for getter`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.subscriptExpectationsSubscript(isGetter: true, isPublic: true).formatted().description
        #expect(result.contains("public subscript(key: Parameter<Int>) -> TestMock.SubscriptExpectation<(Int) -> String"))
        #expect(result.contains(".init("))
        #expect(result.contains("method: Methods.\(sut.getterStubIdentifier)"))
        #expect(result.contains("parameters: [key.anyParameter]"))
    }

    @Test func `subscriptExpectationsSubscript for setter`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.subscriptExpectationsSubscript(isGetter: false, isPublic: true).formatted().description
        #expect(result.contains("public subscript(key: Parameter<Int>) -> TestMock.SubscriptExpectation<(Int, String"))
        #expect(result.contains(".init("))
        #expect(result.contains("method: Methods.\(sut.setterStubIdentifier)"))
        #expect(result.contains("parameters: [key.anyParameter]"))
    }

    @Test func `getterFunctionType for single labeled parameter`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.getterFunctionType.description.trimmingCharacters(in: .whitespaces)
        #expect(result == "(Int) -> String")
    }

    @Test func `getterFunctionType for anonymous parameter`() throws {
        let syntax = Parser.parse(source: "subscript(_ index: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.getterFunctionType.description.trimmingCharacters(in: .whitespaces)
        #expect(result == "(Int) -> String")
    }

    @Test func `setterFunctionType for single parameter`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        let result = sut.setterFunctionType.description.replacingOccurrences(of: " ", with: "")
        #expect(result == "(Int,String)->Void")
    }
}
